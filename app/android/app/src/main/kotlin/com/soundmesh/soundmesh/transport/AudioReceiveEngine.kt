package com.soundmesh.soundmesh.transport

import android.os.SystemClock
import android.util.Log
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
) {
    private val TAG = "AudioReceiveEngine"

    companion object {
        // Jitter buffer: target 100ms = 5 packets at 20ms each
        const val JITTER_BUFFER_PACKETS = 5
        const val MIN_HEALTHY_PACKETS = 2
    }

    private val isReceiving = AtomicBoolean(false)
    private var currentGeneration = 0L
    private var expectedSequence = 0
    private var sessionId: String? = null
    private var sampleRate = 0
    private var channelCount = 0

    // Ring buffer for jitter buffering (indexed by sequenceNumber % capacity)
    private val jitterBuffer = Array<AudioPacket?>(JITTER_BUFFER_PACKETS * 2) { null } // 2x for wrap safety
    private var bufferHead = 0 // Oldest sequence in buffer
    private var bufferTail = 0 // Next sequence to write

    // Statistics
    private val packetsReceived = AtomicLong(0)
    private val packetsLost = AtomicLong(0)
    private val packetsOutOfOrder = AtomicLong(0)
    private val bufferUnderruns = AtomicLong(0)
    private val bufferOverruns = AtomicLong(0)
    private var statsJob: Job? = null

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
            expectedSequence = 0
        }
    }

    /**
     * Start receiving (called on AUDIO_STREAM_START).
     */
    suspend fun onStreamStart(generation: Long) {
        if (generation != currentGeneration) {
            Log.w(TAG, "Stream start for wrong generation: $generation (current: $currentGeneration)")
            return
        }
        if (isReceiving.getAndSet(true)) {
            Log.w(TAG, "onStreamStart called but already receiving")
            return
        }

        // Start periodic stats reporting
        statsJob = scope.launch(Dispatchers.IO) { statsReporter() }

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

        notifyStreamState("STOPPED", null)
        Log.i(TAG, "Receiving stopped for generation $generation")
    }

    /**
     * Process an incoming audio packet.
     */
    fun onAudioPacket(packet: AudioPacket) {
        if (!isReceiving.get()) return

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

        val seq = packet.sequenceNumber

        // Periodic logging for packet flow verification (every 50 packets ~ 1 second)
        if (seq % 50 == 0) {
            Log.i(TAG, "Received packet: seq=$seq generation=$currentGeneration bufferDepth=${getBufferDepth()}")
        }

        // Handle sequence wrapping (unlikely with 32-bit but be safe)
        if (seq < expectedSequence) {
            // Duplicate or very late packet
            Log.d(TAG, "Duplicate/late packet: seq=$seq (expected=$expectedSequence)")
            return
        }

        // Gap detection
        if (seq > expectedSequence) {
            val gap = seq - expectedSequence
            packetsLost.addAndGet(gap.toLong())
            packetsOutOfOrder.incrementAndGet()
            Log.w(TAG, "Packet gap detected: expected=$expectedSequence got=$seq (gap=$gap)")
            expectedSequence = seq
        }

        // Insert into jitter buffer
        val index = seq % jitterBuffer.size
        val existing = jitterBuffer[index]

        if (existing != null) {
            // Overrun - buffer slot already occupied (wrapped around)
            bufferOverruns.incrementAndGet()
            Log.w(TAG, "Jitter buffer overrun at index $index (seq=$seq)")
        }

        jitterBuffer[index] = packet
        bufferTail = seq + 1
    }

    /**
     * Get the next packet in sequence for output (called by Phase 9 output engine).
     * Returns null if not yet available (underrun).
     */
    fun pollNextPacket(): AudioPacket? {
        if (!isReceiving.get()) return null

        val index = expectedSequence % jitterBuffer.size
        val packet = jitterBuffer[index]

        if (packet == null) {
            // Underrun - packet not yet arrived
            bufferUnderruns.incrementAndGet()
            return null
        }

        // Packet available - consume it
        jitterBuffer[index] = null
        expectedSequence++
        bufferHead = expectedSequence
        return packet
    }

    /**
     * Peek at buffer depth without consuming.
     */
    fun getBufferDepth(): Int {
        var depth = 0
        for (i in expectedSequence until bufferTail) {
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
        expectedSequence = 0
        sessionId = null
        sampleRate = 0
        channelCount = 0
        for (i in jitterBuffer.indices) jitterBuffer[i] = null
        bufferHead = 0
        bufferTail = 0
        packetsReceived.set(0)
        packetsLost.set(0)
        packetsOutOfOrder.set(0)
        bufferUnderruns.set(0)
        bufferOverruns.set(0)
        statsJob?.cancel()
        statsJob = null
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
        )
    }
}