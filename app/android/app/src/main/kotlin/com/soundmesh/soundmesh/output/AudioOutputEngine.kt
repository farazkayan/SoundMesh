package com.soundmesh.soundmesh.output

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTimestamp
import android.media.AudioTrack
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.soundmesh.soundmesh.AudioOutputPlatform
import com.soundmesh.soundmesh.DriftStatus
import com.soundmesh.soundmesh.OutputState
import com.soundmesh.soundmesh.ScheduleResult
import com.soundmesh.soundmesh.transport.AudioPacket
import com.soundmesh.soundmesh.transport.AudioReceiveEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.abs

// --- Drift Detection (Phase 15) ---
// Monitors effective synchronization drift by combining:
//   1. Frame-position regression (AudioTrack framePosition vs BOOTTIME)
//   2. Phase 11 offset trend regression (offsetEstimate vs BOOTTIME)
// The sum cancels the network-trend term under the derived observation model.
// Reports driftMsPerSecond as EFFECTIVE synchronization drift rate (not pure audio hardware drift).
// Suspend/resume detected via MONOTONIC/BOOTTIME discontinuity.
private const val DRIFT_MIN_SAMPLES = 10
private const val DRIFT_MIN_TIME_SPAN_NS = 30_000_000_000L // 30s
private const val DRIFT_MAX_SAMPLE_AGE_NS = 120_000_000_000L // 120s
private const val DRIFT_SUSPEND_THRESHOLD_NS = 500_000_000L // 500ms deltaNs jump

private enum class DriftState {
    UNKNOWN, CALIBRATING, SYNCHRONIZED, DEGRADED, FAILED
}

private data class DriftSample(
    val timestampNs: Long,        // participant BOOTTIME (elapsedRealtimeNanos)
    val actualFramePos: Long,     // AudioTrack framePosition
    val expectedFramePos: Double, // from Phase 13 timeline + Phase 11 offset
    val offsetEstimateMs: Double, // Phase 11 offset estimate
    val generation: Long
)

private class DriftMonitor(
    private val scope: CoroutineScope,
    private val getCurrentGeneration: () -> Long,
    private val getStartedAtNanos: () -> Long,
    private val getSampleRate: () -> Int,
    private val getOffsetEstimateMs: () -> Double?, // Phase 11 offset in ms
    private val getSyncState: () -> String,         // Phase 11 sync state
    private val getOutputHealth: () -> Boolean,     // output healthy (no underrun)
    private val notifyDrift: suspend (DriftStatus) -> Unit
) {
    private val samples = mutableListOf<DriftSample>()
    private var currentState = DriftState.UNKNOWN
    private var lastMonoTimeNs: Long? = null
    private var lastBoottimeNs: Long? = null
    private var segmentStartIndex = 0

    suspend fun onTimestampSample(
        framePos: Long,
        frameTsMono: Long,
        boottimeNs: Long,
        expectedFramePos: Double,
        offsetEstimateMs: Double?
    ) {
        val generation = getCurrentGeneration()
        if (generation == 0L) return

        // Suspend detection: MONOTONIC vs BOOTTIME discontinuity
        if (lastMonoTimeNs != null && lastBoottimeNs != null) {
            val monoDelta = frameTsMono - lastMonoTimeNs!!
            val bootDelta = boottimeNs - lastBoottimeNs!!
            val deltaNs = bootDelta - monoDelta // BOOTTIME advances during suspend, MONOTONIC pauses
            if (deltaNs > DRIFT_SUSPEND_THRESHOLD_NS) {
                Log.w("DriftMonitor", "Suspend detected: deltaNs=$deltaNs, resetting segment")
                resetSegment(generation)
            }
        }
        lastMonoTimeNs = frameTsMono
        lastBoottimeNs = boottimeNs

        // Output health check
        if (!getOutputHealth()) {
            Log.w("DriftMonitor", "Output unhealthy (underrun), invalidating segment")
            resetSegment(generation)
            return
        }

        // Phase 11 sync state check
        val syncState = getSyncState()
        if (syncState != "SYNCHRONIZED" && syncState != "DEGRADED") {
            // Not synchronized enough for drift measurement
            return
        }

        val offsetMs = offsetEstimateMs ?: return
        val sample = DriftSample(
            timestampNs = boottimeNs,
            actualFramePos = framePos,
            expectedFramePos = expectedFramePos,
            offsetEstimateMs = offsetMs,
            generation = generation
        )

        // Add sample, enforce max age
        samples.add(sample)
        purgeOldSamples(boottimeNs)

        // Only evaluate if we have enough valid samples in current segment
        val segmentSamples = samples.subList(segmentStartIndex, samples.size)
        if (segmentSamples.size >= DRIFT_MIN_SAMPLES) {
            evaluateDrift(segmentSamples)
        }
    }

    private fun purgeOldSamples(nowNs: Long) {
        while (samples.isNotEmpty() && nowNs - samples.first().timestampNs > DRIFT_MAX_SAMPLE_AGE_NS) {
            samples.removeAt(0)
            if (segmentStartIndex > 0) segmentStartIndex--
        }
    }

    private fun resetSegment(generation: Long) {
        segmentStartIndex = samples.size
        currentState = DriftState.UNKNOWN
        // Emit UNKNOWN status
        scope.launch {
            notifyDrift(DriftStatus(
                state = "UNKNOWN",
                generation = generation,
                validSampleCount = 0L,
                timeSpanNs = 0L
            ))
        }
    }

    fun onGenerationChange(newGeneration: Long) {
        if (newGeneration != getCurrentGeneration()) {
            samples.clear()
            segmentStartIndex = 0
            currentState = DriftState.UNKNOWN
            lastMonoTimeNs = null
            lastBoottimeNs = null
        }
    }

    fun onOutputStop() {
        samples.clear()
        segmentStartIndex = 0
        currentState = DriftState.UNKNOWN
        lastMonoTimeNs = null
        lastBoottimeNs = null
    }

    private fun evaluateDrift(segmentSamples: List<DriftSample>) {
        val gen = getCurrentGeneration()
        if (segmentSamples.isEmpty()) return

        // Need minimum time span
        val first = segmentSamples.first()
        val last = segmentSamples.last()
        val timeSpanNs = last.timestampNs - first.timestampNs
        if (timeSpanNs < DRIFT_MIN_TIME_SPAN_NS) {
            emitState(gen, DriftState.CALIBRATING, null, null, segmentSamples.size, timeSpanNs)
            return
        }

        // ---- drift_local: slope of (actualFramePos - expectedFramePos) vs timestampNs ----
        val driftLocal = computeSlope(
            segmentSamples.map { it.timestampNs.toDouble() },
            segmentSamples.map { (it.actualFramePos - it.expectedFramePos).toDouble() }
        )

        // ---- drift_offset: slope of offsetEstimateMs vs timestampNs ----
        val driftOffset = computeSlope(
            segmentSamples.map { it.timestampNs.toDouble() },
            segmentSamples.map { it.offsetEstimateMs }
        )

        if (driftLocal == null || driftOffset == null) {
            emitState(gen, DriftState.CALIBRATING, null, null, segmentSamples.size, timeSpanNs)
            return
        }

        // drift_effective = drift_local + drift_offset (network trend cancels)
        // Convert from frames/ns to ms/s
        val sampleRate = getSampleRate().toDouble()
        val driftEffectiveFramesPerNs = driftLocal + driftOffset / 1000.0 * (sampleRate / 1_000_000_000.0)
        val driftMsPerSecond = driftEffectiveFramesPerNs * 1_000_000_000.0 / sampleRate * 1000.0

        // State machine (thresholds UNDECIDED - no evidence-backed values in repo)
        val newState = when (currentState) {
            DriftState.UNKNOWN, DriftState.CALIBRATING -> {
                if (abs(driftMsPerSecond!!) <= 1.0) DriftState.SYNCHRONIZED else DriftState.DEGRADED
            }
            DriftState.SYNCHRONIZED -> {
                if (abs(driftMsPerSecond!!) > 5.0) DriftState.DEGRADED else DriftState.SYNCHRONIZED
            }
            DriftState.DEGRADED -> {
                if (abs(driftMsPerSecond!!) <= 1.0) DriftState.SYNCHRONIZED else DriftState.DEGRADED
            }
            DriftState.FAILED -> DriftState.FAILED
        }

        currentState = newState
        emitState(gen, newState, driftMsPerSecond, null, segmentSamples.size, timeSpanNs)
    }

    private fun computeSlope(x: List<Double>, y: List<Double>): Double? {
        val n = x.size
        if (n < 2) return null
        val sumX = x.sum()
        val sumY = y.sum()
        val sumXY = x.zip(y).sumOf { (a, b) -> a * b }
        val sumX2 = x.sumOf { it * it }
        val denom = n * sumX2 - sumX * sumX
        if (denom == 0.0) return null
        return (n * sumXY - sumX * sumY) / denom
    }

    private fun emitState(
        gen: Long,
        state: DriftState,
        driftMsPerSecond: Double?,
        confidence: Double?,
        sampleCount: Int,
        timeSpanNs: Long
    ) {
        val driftStatus = DriftStatus(
            state = state.name,
            driftMsPerSecond = driftMsPerSecond,
            confidence = null, // Per contract: no defensible confidence model
            generation = gen,
            validSampleCount = sampleCount.toLong(),
            timeSpanNs = timeSpanNs
        )
        scope.launch {
            notifyDrift(driftStatus)
        }
    }
}

/**
 * Phase 9 — Audio Output Engine using Android AudioTrack.
 *
 * Consumes PCM frames from AudioReceiveEngine's jitter buffer and renders
 * them through the Android AudioTrack API.
 *
 * All audio processing stays native (Kotlin); only aggregate state crosses to Flutter
 * via Pigeon (AudioOutputFlutterApi).
 *
 * Lifecycle tied to stream state:
 *   STREAMING -> output starts
 *   STOPPED -> output stops
 *
 * States: IDLE, STARTING, PLAYING, UNDERRUN, STOPPED, ERROR
 *
 * Note: For Phase 9, we use immediate playback as an EXPERIMENTAL interim behavior.
 * Phase 11 will replace this with scheduled playback against a shared timeline.
 */
class AudioOutputEngine(
    private val context: Context,
    private val scope: CoroutineScope,
    /** Notify Flutter of output state changes (STARTED/UNDERRUN/STOPPED/ROUTE_CHANGED/ERROR). */
    private val notifyOutputState: suspend (state: String, errorCode: String?, errorMessage: String?) -> Unit,
    /** Provide current sync state for preparation barrier (SYNCHRONIZED/DEGRADED/UNSYNCHRONIZED/etc). */
    private val getSyncState: () -> String = { "UNKNOWN" },
    /** Provide current Phase 11 clock offset estimate in ms. */
    private val getOffsetEstimateMs: () -> Double = { 0.0 },
    /** Binary messenger for Flutter communication (DriftFlutterApi). */
    private val binaryMessenger: io.flutter.plugin.common.BinaryMessenger,
) : AudioOutputPlatform {
    private val TAG = "AudioOutputEngine"

    private val isOutputting = AtomicBoolean(false)
    private val isInitialized = AtomicBoolean(false)
    private var currentSampleRate = 0
    private var currentChannelCount = 0
    private var currentGeneration = 0L
    private var streamStartedAtNanos = 0L
    private var drainJob: Job? = null
    private var audioTrack: AudioTrack? = null
    private var receiveEngine: AudioReceiveEngine? = null

    // Frame timing: 20ms per frame at 44.1kHz stereo 16-bit = 3528 bytes
    private val frameSizeBytes = AtomicLong(0)
    private val frameDurationMs = 20L

    // Audio route monitoring
    private var audioManager: AudioManager? = null
    private var lastKnownDeviceId = -1

    // --- Phase 13: Scheduled playback ---
    private var pendingScheduleTargetTimeNs = 0L
    private var pendingScheduleFrame = 0L
    private var hasPendingSchedule = false

    // Diagnostic counters
    private val packetsWritten = AtomicLong(0)
    private val bytesWritten = AtomicLong(0)
    private val writeErrors = AtomicLong(0)
    private val underrunsReported = AtomicLong(0)

    // --- Phase 12: Output timestamp diagnostics ---
    // Circular buffer for output timestamp samples (write + AudioTrack.getTimestamp())
    companion object {
        const val OUTPUT_DIAG_CAPACITY = 50
        // Ring buffer for write timestamps keyed by frame position (for correlation)
        const val WRITE_TIMESTAMP_RING_SIZE = 1024
    }
    private val outputDiagFrames = Array<OutputTimestampDiag?>(OUTPUT_DIAG_CAPACITY) { null }
    private var outputDiagHead = 0
    private val outputDiagCount = AtomicLong(0)

    // Ring buffer: framePosition % WRITE_TIMESTAMP_RING_SIZE -> writeTimestampNs
    private val writeTimestampRing = LongArray(WRITE_TIMESTAMP_RING_SIZE) { -1L }

    // Cumulative frame tracking for AudioTrack timestamp correlation
    private val cumulativeFramesWritten = AtomicLong(0)

    data class OutputTimestampDiag(
        val sequence: Int,
        val writeTimestampNs: Long,
        val frameStart: Long,
        val framesWritten: Int,
        val cumulativeFramesWritten: Long,
        val audioTrackFramePosition: Long,
        val audioTrackTimestampNs: Long,
        val audioTrackTimestampAvailable: Boolean,
        val audioTrackTimebase: Int,
        val clockDomainAligned: Boolean,
        val correlationValid: Boolean,
        val presentationLatencyNs: Long?
    )

    private var diagJob: Job? = null
    private var driftMonitor: DriftMonitor? = null

    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager?
    }

    /**
     * Set the receive engine to pull packets from.
     * Must be called before onStreamStart().
     */
    fun setReceiveEngine(engine: AudioReceiveEngine) {
        receiveEngine = engine
    }

    /**
     * Initialize output engine with format from stream info.
     * Called when AUDIO_STREAM_INFO is received with a new generation.
     */
    fun onStreamInfo(generation: Long, sampleRate: Int, channelCount: Int, startedAtNanos: Long = 0L) {
        Log.i(TAG, "onStreamInfo called: generation=$generation, currentGeneration=$currentGeneration, sampleRate=$sampleRate, channelCount=$channelCount, startedAtNanos=$startedAtNanos")
        if (generation > currentGeneration) {
            Log.i(TAG, "New stream generation for output: $generation (was $currentGeneration), format=${sampleRate}Hz/${channelCount}ch")
            driftMonitor?.onGenerationChange(generation)
            reset()
            currentGeneration = generation
            currentSampleRate = sampleRate
            currentChannelCount = channelCount
            streamStartedAtNanos = startedAtNanos

            // Calculate frame size in bytes (20ms at sampleRate, channelCount, 16-bit)
            val frameSize = (sampleRate.toLong() * channelCount * 2 * frameDurationMs / 1000)
            frameSizeBytes.set(frameSize)

            // Create AudioTrack
            val success = createAudioTrack(sampleRate, channelCount)
            isInitialized.set(success)
            if (!success) {
                scope.launch {
                    notifyOutputState("ERROR", "OUTPUT_INIT_FAILED", "Failed to create AudioTrack")
                }
            }
        }
    }

    private fun createAudioTrack(sampleRate: Int, channelCount: Int): Boolean {
        try {
            val channelConfig = if (channelCount == 1) {
                AudioFormat.CHANNEL_OUT_MONO
            } else {
                AudioFormat.CHANNEL_OUT_STEREO
            }

            val audioFormat = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(channelConfig)
                .build()

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            // Calculate buffer size - 20ms frames, target ~100ms buffer (5 frames)
            // 5 frames = 100ms, safely above jitter buffer (60ms) and device minimum
            val frameSize = (sampleRate * channelCount * 2 * 20 / 1000) // bytes per 20ms frame
            val bufferSize = frameSize * 5 // ~100ms buffer
            val minBufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, AudioFormat.ENCODING_PCM_16BIT)
            val finalBufferSize = maxOf(bufferSize, minBufferSize)

            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(finalBufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            if (audioTrack!!.state != AudioTrack.STATE_INITIALIZED) {
                Log.e(TAG, "AudioTrack failed to initialize: ${audioTrack!!.state}")
                audioTrack?.release()
                audioTrack = null
                return false
            }

            Log.i(TAG, "AudioTrack created: sampleRate=$sampleRate, channelCount=$channelCount, bufferSize=$finalBufferSize")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioTrack", e)
            return false
        }
    }

    /**
     * Start output (called on AUDIO_STREAM_START).
     */
    suspend fun onStreamStart(generation: Long) {
        Log.i(TAG, "onStreamStart called: generation=$generation, currentGeneration=$currentGeneration, isOutputting=${isOutputting.get()}, isInitialized=${isInitialized.get()}")
        // Be lenient: accept if generation matches OR if we haven't received stream info yet (currentGeneration == 0)
        // This handles the case where AUDIO_STREAM_START arrives before AUDIO_STREAM_INFO is processed
        if (currentGeneration != 0L && generation != currentGeneration) {
            Log.w(TAG, "Stream start for wrong generation: $generation (current: $currentGeneration)")
            return
        }
        if (isOutputting.get()) {
            Log.w(TAG, "Output already running")
            return
        }

        // If we received stream start before stream info, adopt the generation
        if (currentGeneration == 0L) {
            currentGeneration = generation
            Log.i(TAG, "Adopting generation from AUDIO_STREAM_START: $generation")
        }

        if (!isInitialized.get()) {
            Log.w(TAG, "Cannot start output: not initialized (stream info may not have been processed yet)")
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_NOT_READY", "Output engine not initialized")
            }
            return
        }

        if (receiveEngine == null) {
            Log.e(TAG, "Cannot start output: receiveEngine not set")
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_NOT_READY", "Receive engine not connected")
            }
            return
        }

        // Start AudioTrack first
        val track = audioTrack!!

        // Prime AudioTrack with one frame of silence to avoid startup crackle
        // This writes silence to the native buffer before play() begins rendering
        val silenceBytes = frameSizeBytes.get().toInt()
        val silence = ByteArray(silenceBytes)
        var written = 0
        while (written < silenceBytes) {
            val result = track.write(silence, written, silenceBytes - written, AudioTrack.WRITE_BLOCKING)
            if (result < 0) {
                Log.e(TAG, "AudioTrack silence write error: $result")
                break
            }
            written += result
        }
        Log.i(TAG, "AudioTrack primed with ${written}B silence")

        track.play()
        var playState = track.playState
        var waitCount = 0
        while (playState != AudioTrack.PLAYSTATE_PLAYING && waitCount < 50 && isOutputting.get()) {
            Thread.sleep(10)
            playState = track.playState
            waitCount++
        }

        if (playState != AudioTrack.PLAYSTATE_PLAYING) {
            Log.e(TAG, "AudioTrack failed to reach PLAYING state: $playState after ${waitCount * 10}ms")
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_INIT_FAILED", "AudioTrack failed to start: state=$playState")
            }
            return
        }

        Log.i(TAG, "AudioTrack reached PLAYING state after ${waitCount * 10}ms")

        // Wait for receive buffer to reach healthy level before starting playback
        // This prevents initial underrun storm. Timeout after ~500ms.
        val receiveEngineRef = receiveEngine!!
        var bufferReady = false
        var waitCount2 = 0
        while (!bufferReady && waitCount2 < 50) {
            if (receiveEngineRef.isHealthy()) {
                bufferReady = true
                Log.i(TAG, "Receive buffer healthy, depth=${receiveEngineRef.getBufferDepth()} packets, ${receiveEngineRef.getBufferDepthMs()}ms")
            } else {
                Thread.sleep(10)
                waitCount2++
            }
        }
        if (!bufferReady) {
            Log.w(TAG, "Starting playback with unhealthy buffer (depth=${receiveEngineRef.getBufferDepth()}) after ${waitCount2 * 10}ms timeout")
        }

        // Start the frame drain coroutine immediately after buffer readiness
        // Synchronization runs in background; Phase 13 does not block audio on sync
        isOutputting.set(true)
        
        // Initialize DriftMonitor (Phase 15)
        driftMonitor = DriftMonitor(
            scope = scope,
            getCurrentGeneration = { currentGeneration },
            getStartedAtNanos = { streamStartedAtNanos },
            getSampleRate = { currentSampleRate },
            getOffsetEstimateMs = { getOffsetEstimateMs() },
            getSyncState = { getSyncState() },
            getOutputHealth = { isOutputting.get() && audioTrack?.playState == AudioTrack.PLAYSTATE_PLAYING },
            notifyDrift = { status -> 
                // Notify Flutter via DriftFlutterApi
                try {
                    val api = com.soundmesh.soundmesh.DriftFlutterApi(binaryMessenger)
                    api.onDriftStatusChanged(status)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to notify drift status", e)
                }
            }
        )
        
        drainJob = scope.launch(Dispatchers.IO) { drainFrames() }
        diagJob = scope.launch(Dispatchers.IO) { diagnosticsReporter() }

        Log.i(TAG, "Output started for generation $generation")
        scope.launch {
            notifyOutputState("OUTPUT_STARTED", null, null)
        }
    }

    /**
     * Stop output (called on AUDIO_STREAM_STOP or generation change).
     */
    suspend fun onStreamStop(generation: Long) {
        Log.i(TAG, "onStreamStop called: generation=$generation, currentGeneration=$currentGeneration, isOutputting=${isOutputting.get()}")
        if (generation != currentGeneration) {
            Log.d(TAG, "Stream stop for old generation: $generation (current: $currentGeneration)")
            return
        }
        if (!isOutputting.getAndSet(false)) {
            Log.d(TAG, "Output stop called but not outputting")
            return
        }

        // Clear any pending schedule
        hasPendingSchedule = false
        pendingScheduleTargetTimeNs = 0L
        pendingScheduleFrame = 0L

        driftMonitor?.onOutputStop()
        
        drainJob?.cancel()
        drainJob = null

        diagJob?.cancel()
        diagJob = null

        audioTrack?.stop()
        audioTrack?.flush()
        audioTrack?.release()
        audioTrack = null

        Log.i(TAG, "Output stopped for generation $generation")
        scope.launch {
            notifyOutputState("OUTPUT_STOPPED", null, null)
        }
    }

    /**
     * Drain frames from receive engine's jitter buffer and write to AudioTrack.
     * Runs on IO dispatcher.
     * Respects pending schedule target time at frame boundaries (Phase 13).
     */
    private suspend fun drainFrames() {
        try {
            while (isOutputting.get()) {
                // CHECK SCHEDULE AT EVERY FRAME BOUNDARY
                if (hasPendingSchedule) {
                    val nextPacket = receiveEngine?.peekNextPacket()
                    if (nextPacket == null) {
                        delay(frameDurationMs)
                        continue
                    }
                    val nextFramePos = nextPacket.sequenceNumber * 882L
                    val nowNs = SystemClock.elapsedRealtimeNanos()

                    when {
                        nextFramePos < pendingScheduleFrame -> {
                            // Next frame is before target - continue normal playback
                        }
                        nextFramePos == pendingScheduleFrame -> {
                            // At target frame boundary
                            if (nowNs < pendingScheduleTargetTimeNs) {
                                // Wait until target time
                                val waitMs = ((pendingScheduleTargetTimeNs - nowNs) / 1_000_000).coerceAtMost(10).toLong()
                                delay(waitMs)
                                continue
                            }
                            // Target reached or slightly missed - consume frame, clear schedule
                            hasPendingSchedule = false
                            pendingScheduleFrame = 0L
                            pendingScheduleTargetTimeNs = 0L
                        }
                        nextFramePos > pendingScheduleFrame -> {
                            // Target frame already passed - schedule missed
                            hasPendingSchedule = false
                            pendingScheduleFrame = 0L
                            pendingScheduleTargetTimeNs = 0L
                        }
                    }
                }

                // Normal packet consumption
                val packet = receiveEngine?.pollNextPacket()
                if (packet == null) {
                    // Underrun - no packet available yet
                    underrunsReported.incrementAndGet()
                    delay(frameDurationMs)
                    continue
                }

                val written = writeToAudioTrack(packet)

                if (written > 0) {
                    packetsWritten.incrementAndGet()
                    bytesWritten.addAndGet(written.toLong())
                }

                if (written < packet.payload.size) {
                    Log.w(TAG, "Partial write: $written/${packet.payload.size} bytes, seq=${packet.sequenceNumber}")
                    writeErrors.incrementAndGet()
                    scope.launch {
                        notifyOutputState("OUTPUT_UNDERRUN", "OUTPUT_UNDERRUN", "Output buffer underrun (partial write)")
                    }
                }
                // No delay on full write - WRITE_BLOCKING naturally paces playback
            }
        } catch (e: Exception) {
            Log.e(TAG, "Drain loop failed", e)
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_FAILURE", "Drain loop failed: ${e.message}")
            }
        }
    }

    /**
     * Request a schedule target for the next frame from Dart TimelineProvider.
     * Called when no schedule exists yet (startup or after previous schedule cleared).
     * Note: In the current architecture, Dart TimelineProvider drives scheduling
     * by polling getNextFrameInfo() and calling scheduleFrame(). Native does not
     * request schedule targets from Dart.
     */
    private fun requestScheduleForNextFrame() {
        // In the current architecture, Dart TimelineProvider drives scheduling
        // by polling getNextFrameInfo() and calling scheduleFrame().
        // Native does not request schedule targets from Dart.
    }

    private fun writeToAudioTrack(packet: AudioPacket): Int {
        val track = audioTrack ?: return 0
        val playState = track.playState

        if (playState != AudioTrack.PLAYSTATE_PLAYING) {
            Log.w(TAG, "writeToAudioTrack: playState=$playState (expected PLAYING), seq=${packet.sequenceNumber}")
            return 0
        }

        // Diagnostic: log PCM stats at write point (first 10 packets per session)
        if (packetsWritten.get() < 10) {
            var peak = 0
            var nonZero = 0
            for (i in 0 until packet.payload.size step 2) {
                if (i + 1 < packet.payload.size) {
                    val s = (packet.payload[i + 1].toInt() shl 8) or (packet.payload[i].toInt() and 0xFF)
                    val a = if (s < 0) -s else s
                    if (a > peak) peak = a
                    if (a > 0) nonZero++
                }
            }
            Log.i(TAG, "PCM write: seq=${packet.sequenceNumber} bytes=${packet.payload.size} peak=$peak nonZero=$nonZero/${packet.payload.size/2}")
        }

        // Phase 12: Record write timestamp and frame position before write
        val framesInPacket = packet.payload.size / (currentChannelCount * 2) // 2 bytes per sample
        val writeTimestampNs = SystemClock.elapsedRealtimeNanos()
        val frameStart = cumulativeFramesWritten.getAndAdd(framesInPacket.toLong())

        // Store write timestamps in ring buffer for frame-position correlation
        // Each frame in this packet gets the same write timestamp
        for (f in 0 until framesInPacket) {
            val framePos = frameStart + f
            writeTimestampRing[framePos.toInt() % WRITE_TIMESTAMP_RING_SIZE] = writeTimestampNs
        }

        var offset = 0
        val totalBytes = packet.payload.size
        while (offset < totalBytes && isOutputting.get()) {
            val bytesToWrite = minOf(totalBytes - offset, 4096)
            val written = track.write(packet.payload, offset, bytesToWrite, AudioTrack.WRITE_BLOCKING)
            if (written < 0) {
                Log.e(TAG, "AudioTrack write error: $written (seq=${packet.sequenceNumber})")
                writeErrors.incrementAndGet()
                return offset
            }
            if (written == 0) {
                // WRITE_BLOCKING should not return 0, but handle defensively
                Log.w(TAG, "AudioTrack.write returned 0, retrying...")
                Thread.sleep(1)
                continue
            }
            offset += written
        }

        // Phase 12: AudioTrack.getTimestamp() probe at frame boundary
        // Called after successful packet write to correlate presentation time
        var audioTrackFramePosition: Long = -1
        var audioTrackTimestampNs: Long = -1
        var audioTrackTimestampAvailable = false
        var audioTrackTimebase = AudioTimestamp.TIMEBASE_MONOTONIC
        var clockDomainAligned = false
        var correlationValid = false
        var presentationLatencyNs: Long? = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val audioTimestamp = AudioTimestamp()
            var timebase = AudioTimestamp.TIMEBASE_MONOTONIC
            // Use parameterless getTimestamp() for all API levels to avoid overload resolution issues
            // On API 29+, this uses TIMEBASE_MONOTONIC by default; TIMEBASE_BOOTTIME requires the 2-arg overload
            val result = track.getTimestamp(audioTimestamp)
            // On API 29+, the parameterless version uses MONOTONIC; we note this
            timebase = AudioTimestamp.TIMEBASE_MONOTONIC
            if (result) {
                audioTrackFramePosition = audioTimestamp.framePosition
                audioTrackTimestampNs = audioTimestamp.nanoTime
                audioTrackTimestampAvailable = true
                // Clock domain aligned with elapsedRealtimeNanos() only when timebase is BOOTTIME
                // Since we use parameterless getTimestamp() (always MONOTONIC), it's NOT aligned
                clockDomainAligned = false

                // Frame correlation: look up write timestamp for the PRESENTED frame
                // AudioTrack timestamp reports frames already presented to hardware
                // We need the write timestamp for that specific frame position
                if (audioTrackFramePosition >= 0) {
                    val ringIdx = audioTrackFramePosition.toInt() % WRITE_TIMESTAMP_RING_SIZE
                    val writeTsForFrame = writeTimestampRing[ringIdx]
                    if (writeTsForFrame > 0) {
                        correlationValid = true
                        // Only compute presentation latency when clock domains are aligned
                        if (clockDomainAligned) {
                            presentationLatencyNs = audioTrackTimestampNs - writeTsForFrame
                        }
                    }
                }
            }
        }

        // Store in circular buffer
        val idx = outputDiagHead % OUTPUT_DIAG_CAPACITY
        outputDiagFrames[idx] = OutputTimestampDiag(
            sequence = packet.sequenceNumber,
            writeTimestampNs = writeTimestampNs,
            frameStart = frameStart,
            framesWritten = framesInPacket,
            cumulativeFramesWritten = cumulativeFramesWritten.get(),
            audioTrackFramePosition = audioTrackFramePosition,
            audioTrackTimestampNs = audioTrackTimestampNs,
            audioTrackTimestampAvailable = audioTrackTimestampAvailable,
            audioTrackTimebase = audioTrackTimebase,
            clockDomainAligned = clockDomainAligned,
            correlationValid = correlationValid,
            presentationLatencyNs = presentationLatencyNs
        )
        outputDiagHead++
        outputDiagCount.incrementAndGet()

        return offset
    }

    /**
     * Get current output state for querying (AudioOutputPlatform).
     */
    override fun getOutputState(): OutputState {
        return if (isOutputting.get()) {
            OutputState(state = "PLAYING", bufferedMs = estimateBufferedMs())
        } else if (isInitialized.get()) {
            OutputState(state = "IDLE", bufferedMs = 0)
        } else {
            OutputState(state = "ERROR", bufferedMs = 0)
        }
    }

    /**
     * Get current output state (alias for getOutputState for internal use).
     */
    fun getState(): OutputState = getOutputState()

    /**
     * Schedule a frame for future playback (Phase 13).
     * Gates the start of drainFrames() until targetNativeTimeNanos is reached.
     */
    override fun scheduleFrame(
        framePosition: Long,
        targetNativeTimeNanos: Long,
        generation: Long
    ): ScheduleResult {
        if (generation != currentGeneration) {
            Log.w(TAG, "scheduleFrame: stale generation $generation (current: $currentGeneration)")
            return ScheduleResult(false, "STALE_GENERATION", "Generation mismatch")
        }
        if (targetNativeTimeNanos <= 0) {
            return ScheduleResult(false, "INVALID_TARGET_TIME", "Target time must be positive")
        }

        pendingScheduleFrame = framePosition
        pendingScheduleTargetTimeNs = targetNativeTimeNanos
        hasPendingSchedule = true

        Log.i(TAG, "scheduleFrame: frame=$framePosition targetNs=$targetNativeTimeNanos gen=$generation")

        // If not already outputting, start the gated output
        if (!isOutputting.get()) {
            startGatedOutput()
        }

        return ScheduleResult(true, null, null)
    }

    private fun startGatedOutput() {
        // The actual gating logic is in onStreamStart - this just ensures
        // the output engine is ready to gate when the stream starts.
        // For late scheduling after stream start, we need to re-gate.
        if (isOutputting.get()) {
            // Already outputting - the drainFrames loop will respect the new target
            Log.i(TAG, "startGatedOutput: already outputting, drainFrames will respect new target")
        }
    }

    private fun estimateBufferedMs(): Long {
        val track = audioTrack ?: return 0
        // Rough estimate based on buffer size and sample rate
        val bufferedFrames = track.playbackHeadPosition
        if (bufferedFrames <= 0) return 0
        return (bufferedFrames * 1000L / currentSampleRate.toLong()).toLong()
    }

    /**
     * Reset all state (called on generation change or error).
     */
    fun reset() {
        Log.w(TAG, "reset() called - currentGeneration=$currentGeneration, isOutputting=${isOutputting.get()}")
        driftMonitor?.onOutputStop()
        isOutputting.set(false)
        isInitialized.set(false)
        currentGeneration = 0
        currentSampleRate = 0
        currentChannelCount = 0
        frameSizeBytes.set(0)
        
        // Phase 13: Clear pending schedule
        hasPendingSchedule = false
        pendingScheduleTargetTimeNs = 0L
        pendingScheduleFrame = 0L
        
        drainJob?.cancel()
        drainJob = null
        diagJob?.cancel()
        diagJob = null

        audioTrack?.stop()
        audioTrack?.flush()
        audioTrack?.release()
        audioTrack = null

        packetsWritten.set(0)
        bytesWritten.set(0)
        writeErrors.set(0)
        underrunsReported.set(0)

        // Phase 12: Reset diagnostic buffers
        outputDiagHead = 0
        outputDiagCount.set(0)
        for (i in outputDiagFrames.indices) outputDiagFrames[i] = null
        for (i in writeTimestampRing.indices) writeTimestampRing[i] = -1L
        cumulativeFramesWritten.set(0)
    }

    /** Periodic diagnostic reporter for pipeline tracing (Phase 12). */
    private suspend fun diagnosticsReporter() {
        try {
            while (isOutputting.get()) {
                delay(2000)
                val bufferDepth = receiveEngine?.getBufferDepth() ?: -1
                val bufferDepthMs = receiveEngine?.getBufferDepthMs() ?: -1

                // Phase 12: Output timestamp diagnostics
                var availableCount = 0L
                var alignedCount = 0L
                var correlationCount = 0L
                var latencySum = 0L
                var latencyMin = Long.MAX_VALUE
                var latencyMax = Long.MIN_VALUE
                var latestDiag: OutputTimestampDiag? = null

                val count = outputDiagCount.get().toInt().coerceAtMost(OUTPUT_DIAG_CAPACITY)
                for (i in 0 until count) {
                    val idx = (outputDiagHead - count + i) % OUTPUT_DIAG_CAPACITY
                    val diag = outputDiagFrames[idx]
                    diag?.let {
                        if (it.audioTrackTimestampAvailable) {
                            availableCount++
                            if (it.clockDomainAligned) {
                                alignedCount++
                            }
                        }
                        if (it.correlationValid) {
                            correlationCount++
                            // Only include latency when clock domains are aligned
                            if (it.clockDomainAligned) {
                                it.presentationLatencyNs?.let { lat ->
                                    latencySum += lat
                                    if (lat < latencyMin) latencyMin = lat
                                    if (lat > latencyMax) latencyMax = lat
                                }
                            }
                        }
                        if (it.sequence > (latestDiag?.sequence ?: -1)) {
                            latestDiag = it
                        }
                    }
                }

                val latencyAvg = if (correlationCount > 0 && alignedCount > 0) latencySum / correlationCount else 0L
                val latencyMinStr = if (latencyMin != Long.MAX_VALUE) latencyMin else "N/A"
                val latencyMaxStr = if (latencyMax != Long.MIN_VALUE) latencyMax else "N/A"
                val timebaseStr = latestDiag?.audioTrackTimebase?.let {
                    when (it) {
                        AudioTimestamp.TIMEBASE_BOOTTIME -> "BOOTTIME"
                        AudioTimestamp.TIMEBASE_MONOTONIC -> "MONOTONIC"
                        else -> "UNKNOWN($it)"
                    }
                } ?: "N/A"
                val alignedStr = latestDiag?.clockDomainAligned?.let { if (it) "ALIGNED" else "UNALIGNED" } ?: "N/A"
                val latestStr = latestDiag?.let {
                    "seq=${it.sequence} writeTs=${it.writeTimestampNs} " +
                    "frameStart=${it.frameStart} frames=${it.framesWritten} " +
                    "cumFrames=${it.cumulativeFramesWritten} " +
                    "atFrame=${it.audioTrackFramePosition} atTs=${it.audioTrackTimestampNs} " +
                    "atAvail=${it.audioTrackTimestampAvailable} tb=$timebaseStr aligned=$alignedStr " +
                    "corr=${it.correlationValid} " +
                    "presLat=${if (it.clockDomainAligned) it.presentationLatencyNs else "N/A"}"
                } ?: "none"

                Log.i(
                    TAG,
                    "[DIAG] AudioOutput: packetsWritten=${packetsWritten.get()} " +
                        "bytesWritten=${bytesWritten.get()} writeErrors=${writeErrors.get()} " +
                        "underruns=${underrunsReported.get()} " +
                        "bufferDepth=$bufferDepth bufferDepthMs=$bufferDepthMs " +
                        "playState=${audioTrack?.playState ?: -1} " +
                        "outputDiag: count=$count atAvail=$availableCount aligned=$alignedCount corr=$correlationCount " +
                        "presAvgNs=$latencyAvg presMin=$latencyMinStr presMax=$latencyMaxStr " +
                        "latest=[$latestStr]"
                )

                // Drift Detection (Phase 15): feed latest valid sample to DriftMonitor
                latestDiag?.let { diag ->
                    if (diag.audioTrackTimestampAvailable && diag.correlationValid) {
                        val boottimeNow = SystemClock.elapsedRealtimeNanos()
                        val expectedFramePos = (diag.cumulativeFramesWritten.toDouble() + 
                            (boottimeNow - diag.writeTimestampNs) * currentSampleRate / 1_000_000_000.0)
                        driftMonitor?.onTimestampSample(
                            framePos = diag.audioTrackFramePosition,
                            frameTsMono = diag.audioTrackTimestampNs,
                            boottimeNs = boottimeNow,
                            expectedFramePos = expectedFramePos,
                            offsetEstimateMs = getOffsetEstimateMs()
                        )
                    }
                }

                // TEMPORARY: Timebase constancy check (Step 1 of Drift Detection)
                // Log AudioTrack timestamp timebase vs SystemClock.elapsedRealtimeNanos() side-by-side
                // to verify constant bias assumption for drift estimation.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val track = audioTrack
                    if (track != null && track.playState == AudioTrack.PLAYSTATE_PLAYING) {
                        // Test 1: MONOTONIC (parameterless getTimestamp, default on API 24+)
                        val audioTimestampMonotonic = AudioTimestamp()
                        val resultMonotonic = track.getTimestamp(audioTimestampMonotonic)
                        if (resultMonotonic) {
                            val audioTrackTs = audioTimestampMonotonic.nanoTime
                            val systemClockTs = SystemClock.elapsedRealtimeNanos()
                            val offsetNs = audioTrackTs - systemClockTs
                            val timebaseName = "MONOTONIC (default)"
                            Log.i(TAG, "[TIMEBASE_CHECK] timebase=$timebaseName audioTrackTs=$audioTrackTs systemClockTs=$systemClockTs offsetNs=$offsetNs framePos=${audioTimestampMonotonic.framePosition}")
                        } else {
                            Log.w(TAG, "[TIMEBASE_CHECK] MONOTONIC getTimestamp returned false")
                        }

                        // Test 2: BOOTTIME (2-arg overload, API 29+) - should align with elapsedRealtimeNanos()
                        // Use reflection to avoid compile-time API level issues
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val audioTimestampBoottime = AudioTimestamp()
                            val timebaseBoottime = AudioTimestamp.TIMEBASE_BOOTTIME
                            var resultBoottime = false
                            try {
                                val method = AudioTrack::class.java.getMethod("getTimestamp", AudioTimestamp::class.java, Int::class.javaPrimitiveType)
                                val result = method.invoke(track, audioTimestampBoottime, timebaseBoottime)
                                resultBoottime = when (result) {
                                    is Boolean -> result
                                    is Int -> result == AudioTrack.SUCCESS
                                    else -> false
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "AudioTrack.getTimestamp BOOTTIME reflection failed", e)
                                resultBoottime = false
                            }
                            if (resultBoottime) {
                                val audioTrackTs = audioTimestampBoottime.nanoTime
                                val systemClockTs = SystemClock.elapsedRealtimeNanos()
                                val offsetNs = audioTrackTs - systemClockTs
                                val timebaseName = "BOOTTIME"
                                Log.i(TAG, "[TIMEBASE_CHECK] timebase=$timebaseName audioTrackTs=$audioTrackTs systemClockTs=$systemClockTs offsetNs=$offsetNs framePos=${audioTimestampBoottime.framePosition}")
                            } else {
                                Log.w(TAG, "[TIMEBASE_CHECK] BOOTTIME getTimestamp returned false")
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Diagnostics reporter failed", e)
        }
    }
}