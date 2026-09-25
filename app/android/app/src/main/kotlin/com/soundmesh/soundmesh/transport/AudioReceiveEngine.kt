package com.soundmesh.soundmesh.transport

import android.os.SystemClock
import android.util.Log
import com.soundmesh.soundmesh.NextFrameInfo
import com.soundmesh.soundmesh.ReceiveState
import com.soundmesh.soundmesh.ReceiveStats
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Participant-side audio receive engine with jitter buffer.
 *
 * Receives AUDIO_PACKET messages, validates generation, reorders by sequence number,
 * maintains a bounded jitter buffer, and detects underruns/overruns/loss.
 *
 * All processing stays native; only aggregate state crosses to Flutter.
 */
class AudioReceiveEngine(
    private val scope: CoroutineScope,
    /** Notify Flutter of receive state changes (STREAMING/RECOVERING/FAILED/STOPPED). */
    private val notifyStreamState: suspend (state: String, stats: ReceiveStats?) -> Unit,
    /** Notify Flutter of audio level updates for visual meter (peakAmplitude 0-32767, isSilent). */
    private val notifyAudioLevel: suspend (peakAmplitude: Int, isSilent: Boolean) -> Unit,
) {
    private val TAG = "AudioReceiveEngine"

    companion object {
        // Jitter buffer: target 60ms = 3 packets at 20ms each (reduced from 100ms for Phase 9 streaming)
        const val JITTER_BUFFER_PACKETS = 3
        const val MIN_HEALTHY_PACKETS = 1
    }

    private val isReceiving = AtomicBoolean(false)
    private var currentGeneration = 0L
    private var readHead = 0 // Next sequence to CONSUME (pollNextPacket)
    private var writeHead = 0 // Highest sequence RECEIVED + 1 (onAudioPacket)
    private var sessionId: String? = null
    private var sampleRate = 0
    private var channelCount = 0

    // Ring buffer for jitter buffering (indexed by sequenceNumber % capacity)
    private val jitterBuffer = Array<AudioPacket?>(JITTER_BUFFER_PACKETS * 2) { null } // 2x for wrap safety
    private var bufferHead = 0 // Oldest sequence in buffer (== readHead when healthy)

    // Statistics
    private val packetsReceived = AtomicLong(0)
    private val packetsLost = AtomicLong(0)
    private val packetsOutOfOrder = AtomicLong(0)
    private val bufferUnderruns = AtomicLong(0)
    private val bufferOverruns = AtomicLong(0)
    
    // --- Diagnostic counters for BUG #3 pipeline tracing ---
    private val lastPacketReceivedTimestampNanos = AtomicLong(0)
    private var receiveDiagJob: Job? = null

    private var statsJob: Job? = null
    private var amplitudeJob: Job? = null

    // Latest audio amplitude for visual meter
    private var latestPeakAmplitude = 0
    private var latestIsSilent = true

    /**
     * Initialize for a new stream (called on AUDIO_STREAM_INFO with new generation).
     */
    fun onStreamInfo(sessionId: String, generation: Long, sampleRate: Int, channelCount: Int) {
        // If generation is newer, reset state
        if (generation > currentGeneration) {
            Log.i(TAG, "New stream generation: $generation (was $currentGeneration)")
            reset()
            currentGeneration = generation
            this.sessionId = sessionId
            this.sampleRate = sampleRate
            this.channelCount = channelCount
            readHead = 0
            writeHead = 0
        }
    }

    /**
     * Start receiving (called on AUDIO_STREAM_START).
     */
    suspend fun onStreamStart(generation: Long) {
        // Be lenient: accept if generation matches OR if we haven't received stream info yet (currentGeneration == 0)
        // This handles the case where AUDIO_STREAM_START arrives before AUDIO_STREAM_INFO is processed
        if (currentGeneration != 0L && generation != currentGeneration) {
            Log.w(TAG, "Stream start for wrong generation: $generation (current: $currentGeneration)")
            return
        }
        if (isReceiving.getAndSet(true)) {
            Log.w(TAG, "onStreamStart called but already receiving")
            return
        }

        // If we received stream start before stream info, adopt the generation
        if (currentGeneration == 0L) {
            currentGeneration = generation
            readHead = 0
            writeHead = 0
            Log.i(TAG, "Adopting generation from AUDIO_STREAM_START: $generation")
        }

        // Reset diagnostic counters
        packetsReceived.set(0)
        packetsLost.set(0)
        packetsOutOfOrder.set(0)
        bufferUnderruns.set(0)
        bufferOverruns.set(0)
        lastPacketReceivedTimestampNanos.set(0)

        // Start periodic stats reporting
        statsJob = scope.launch(Dispatchers.IO) { statsReporter() }
        receiveDiagJob = scope.launch(Dispatchers.IO) { receiveDiagnosticsReporter() }

        // Start fast amplitude reporting for visual meter (~40-60ms updates)
        amplitudeJob = scope.launch(Dispatchers.IO) { amplitudeReporter() }

        notifyStreamState("STREAMING", computeStats())
        Log.i(TAG, "Receiving started for generation $generation")
    }

    /**
     * Stop receiving (called on AUDIO_STREAM_STOP or generation change).
     */
    suspend fun onStreamStop(generation: Long) {
        if (generation != currentGeneration) {
            Log.d(TAG, "Stream stop for old generation: $generation (current: $currentGeneration)")
            return
        }
        if (!isReceiving.getAndSet(false)) {
            Log.d(TAG, "onStreamStop called but not receiving")
            return
        }

        statsJob?.cancel()
        statsJob = null

        amplitudeJob?.cancel()
        amplitudeJob = null

        receiveDiagJob?.cancel()
        receiveDiagJob = null

        // Reset amplitude to zero when stopped
        latestPeakAmplitude = 0
        latestIsSilent = true

        notifyStreamState("STOPPED", null)
        Log.i(TAG, "Receiving stopped for generation $generation")
    }

    /**
     * Process an incoming audio packet.
     */
    fun onAudioPacket(packet: AudioPacket) {
        if (!isReceiving.get()) return

        // If we haven't adopted a generation yet (e.g., packets arrive before STREAM_START),
        // adopt the packet's generation
        if (currentGeneration == 0L) {
            currentGeneration = packet.streamGeneration
            readHead = 0
            writeHead = 0
            Log.i(TAG, "Adopting generation from first AUDIO_PACKET: $currentGeneration")
        }

        // Discard stale generations
        if (packet.streamGeneration < currentGeneration) {
            Log.d(TAG, "Discarding stale generation packet: ${packet.streamGeneration} < $currentGeneration")
            return
        }
        if (packet.streamGeneration > currentGeneration) {
            Log.w(TAG, "Received packet from future generation: ${packet.streamGeneration} > $currentGeneration")
            return
        }

        packetsReceived.incrementAndGet()
        lastPacketReceivedTimestampNanos.set(SystemClock.elapsedRealtimeNanos())

        val seq = packet.sequenceNumber

        // Compute payload audio stats (peak amplitude, silence detection)
        val (peakAmplitude, isSilent) = computePayloadStats(packet.payload)

        // Update latest amplitude for visual meter
        latestPeakAmplitude = peakAmplitude
        latestIsSilent = isSilent

        // Periodic logging for packet flow verification (every 50 packets ~ 1 second)
        if (seq % 50 == 0) {
            Log.i(TAG, "Received packet: seq=$seq generation=$currentGeneration bufferDepth=${getBufferDepth()} peakAmplitude=$peakAmplitude isSilent=$isSilent")
        }

        // Handle sequence wrapping (unlikely with 32-bit but be safe)
        // Packets older than readHead are already consumed or declared lost
        if (seq < readHead) {
            Log.d(TAG, "Duplicate/late packet: seq=$seq (readHead=$readHead)")
            return
        }

        // Track out-of-order arrivals (any packet ahead of readHead)
        if (seq >= readHead) {
            packetsOutOfOrder.incrementAndGet()
        }

        // Update writeHead to track highest received sequence + 1
        // Use max to prevent writeHead from going backwards on out-of-order arrival
        writeHead = maxOf(writeHead, seq + 1)

        // Insert into jitter buffer
        val index = seq % jitterBuffer.size
        val existing = jitterBuffer[index]

        if (existing != null) {
            // Overrun - buffer slot already occupied (wrapped around)
            bufferOverruns.incrementAndGet()
            Log.w(TAG, "Jitter buffer overrun at index $index (seq=$seq) bufferDepth=${getBufferDepth()} readHead=$readHead writeHead=$writeHead")
        }

        jitterBuffer[index] = packet
    }

    /**
     * Compute peak amplitude and silence detection from PCM payload.
     * Payload is 16-bit stereo PCM (2 bytes per sample * 2 channels), little-endian.
     */
    private fun computePayloadStats(payload: ByteArray): kotlin.Pair<Int, Boolean> {
        var peak = 0
        var nonZeroSamples = 0
        // Process as signed 16-bit little-endian samples (2 bytes per sample)
        for (i in 0 until payload.size step 2) {
            if (i + 1 < payload.size) {
                val lowByte = payload[i].toInt() and 0xFF
                val highByte = payload[i + 1].toInt() and 0xFF
                // Correct signed 16-bit reconstruction: little-endian
                val sample = (highByte shl 8) or lowByte
                val absSample = if (sample < 0) -sample else sample
                if (absSample > peak) peak = absSample
                if (absSample > 0) nonZeroSamples++
            }
        }
        // Consider silent if less than 0.1% of samples are non-zero
        val isSilent = nonZeroSamples < (payload.size / 2) / 1000
        return peak to isSilent
    }

    /**
     * Get the next packet in sequence for output (called by Phase 9 output engine).
     * Returns null if not yet available (underrun).
     * If the missing packet is beyond jitter buffer capacity, declares it lost and advances.
     */
    fun pollNextPacket(): AudioPacket? {
        if (!isReceiving.get()) return null

        val index = readHead % jitterBuffer.size
        val packet = jitterBuffer[index]

        if (packet == null) {
            // Underrun - packet not yet arrived
            // Check if we've waited long enough (beyond jitter buffer capacity)
            // writeHead is highest received + 1, so writeHead - readHead = packets ahead available
            if (writeHead - readHead > JITTER_BUFFER_PACKETS) {
                // Missing packet is beyond reordering window — declare genuine loss
                packetsLost.incrementAndGet()
                Log.w(TAG, "Declaring packet $readHead lost (writeHead=$writeHead, gap=${writeHead - readHead})")
                readHead++
                bufferHead = readHead
                bufferUnderruns.incrementAndGet()
                return null
            }
            bufferUnderruns.incrementAndGet()
            return null
        }

        // Packet available - consume it
        jitterBuffer[index] = null
        readHead++
        bufferHead = readHead
        return packet
    }

    /**
     * Peek at buffer depth without consuming.
     */
    fun getBufferDepth(): Int {
        var depth = 0
        for (i in readHead until writeHead) {
            if (jitterBuffer[i % jitterBuffer.size] != null) depth++
        }
        return depth
    }

    /**
     * Get buffer depth in milliseconds.
     */
    fun getBufferDepthMs(): Int {
        if (sampleRate <= 0 || channelCount <= 0) return 0
        val depth = getBufferDepth()
        val bytesPerPacket = (sampleRate * channelCount * 2 * 20 / 1000) // 20ms worth
        val totalBytes = depth * bytesPerPacket
        val ms = (totalBytes * 1000) / (sampleRate * channelCount * 2)
        return ms
    }

    /**
     * Peek at the next packet in sequence without consuming it.
     * Returns null if no packet is available at readHead.
     */
    fun peekNextPacket(): AudioPacket? {
        if (!isReceiving.get()) return null
        val index = readHead % jitterBuffer.size
        return jitterBuffer[index]
    }

    /**
     * Get immutable snapshot of the next frame boundary for scheduling.
     * Returns null if no packet is available at readHead.
     */
    fun getNextFrameInfo(): NextFrameInfo? {
        val packet = peekNextPacket()
        if (packet == null) return null
        return NextFrameInfo(
            framePosition = packet.sequenceNumber * 882L,
            sequenceNumber = packet.sequenceNumber.toLong(),
            generation = packet.streamGeneration,
            sampleRate = packet.sampleRate.toLong(),
            channelCount = packet.channelCount.toLong(),
        )
    }

    /**
     * Check if buffer is healthy (enough packets for stable output).
     */
    fun isHealthy(): Boolean = getBufferDepth() >= MIN_HEALTHY_PACKETS

    /**
     * Current receive state for getReceiveState().
     */
    fun getState(): ReceiveState {
        return if (isReceiving.get()) {
            ReceiveState(state = if (isHealthy()) "STREAMING" else "RECOVERING", stats = computeStats())
        } else {
            ReceiveState(state = "IDLE", stats = null)
        }
    }

    /**
     * Reset all state (called on generation change or error).
     */
    fun reset() {
        isReceiving.set(false)
        currentGeneration = 0
        readHead = 0
        writeHead = 0
        sessionId = null
        sampleRate = 0
        channelCount = 0
        for (i in jitterBuffer.indices) jitterBuffer[i] = null
        bufferHead = 0
        packetsReceived.set(0)
        packetsLost.set(0)
        packetsOutOfOrder.set(0)
        bufferUnderruns.set(0)
        bufferOverruns.set(0)
        lastPacketReceivedTimestampNanos.set(0)
        latestPeakAmplitude = 0
        latestIsSilent = true
        statsJob?.cancel()
        statsJob = null
        amplitudeJob?.cancel()
        amplitudeJob = null
        receiveDiagJob?.cancel()
        receiveDiagJob = null
    }

    private suspend fun statsReporter() {
        try {
            while (isReceiving.get()) {
                notifyStreamState(
                    if (isHealthy()) "STREAMING" else "RECOVERING",
                    computeStats()
                )
                kotlinx.coroutines.delay(500) // Report every 500ms
            }
        } catch (e: Exception) {
            Log.e(TAG, "Stats reporter failed", e)
        }
    }

    /**
     * Fast amplitude reporter for visual meter updates (~40-60ms).
     * Reports latest peak amplitude and silence state to Flutter for real-time VU meter.
     */
    private suspend fun amplitudeReporter() {
        try {
            while (isReceiving.get()) {
                notifyAudioLevel(latestPeakAmplitude, latestIsSilent)
                kotlinx.coroutines.delay(50) // ~20ms * 2.5 packets = 50ms
            }
        } catch (e: Exception) {
            Log.e(TAG, "Amplitude reporter failed", e)
        }
    }

    private fun computeStats(): ReceiveStats {
        val received = packetsReceived.get()
        val lost = packetsLost.get()
        val totalExpected = received + lost
        val lossRate = if (totalExpected > 0) lost.toDouble() / totalExpected else 0.0

        return ReceiveStats(
            packetsReceived = received,
            packetsLost = lost,
            packetsOutOfOrder = packetsOutOfOrder.get(),
            bufferDepthMs = getBufferDepthMs().toLong(),
            lossRate = lossRate,
            timestampNanos = SystemClock.elapsedRealtimeNanos(),
            isHealthy = isHealthy(),
            peakAmplitude = latestPeakAmplitude.toLong(),
            isSilent = latestIsSilent,
        )
    }

    /** Periodic diagnostic reporter for pipeline tracing (BUG #3). */
    private suspend fun receiveDiagnosticsReporter() {
        try {
            while (isReceiving.get()) {
                kotlinx.coroutines.delay(2000)
                val now = SystemClock.elapsedRealtimeNanos()
                val lastPacketAgeMs = if (lastPacketReceivedTimestampNanos.get() > 0) {
                    (now - lastPacketReceivedTimestampNanos.get()) / 1_000_000
                } else -1L
                Log.i(
                    TAG,
                    "[DIAG] AudioReceive: packetsReceived=${packetsReceived.get()} " +
                        "packetsLost=${packetsLost.get()} packetsOutOfOrder=${packetsOutOfOrder.get()} " +
                        "bufferDepth=${getBufferDepth()} bufferDepthMs=${getBufferDepthMs()} " +
                        "underruns=${bufferUnderruns.get()} overruns=${bufferOverruns.get()} " +
                        "lastPacketAgeMs=$lastPacketAgeMs"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Receive diagnostics reporter failed", e)
        }
    }
}