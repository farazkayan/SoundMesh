package com.soundmesh.soundmesh.capture

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.soundmesh.soundmesh.CaptureError
import com.soundmesh.soundmesh.CaptureMetadata
import com.soundmesh.soundmesh.CaptureResult
import com.soundmesh.soundmesh.FrameArrivalStats
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Phase 5 feasibility spike — native capture engine.
 *
 * Owns the full native capture lifecycle:
 *   consent grant → foreground service → MediaProjection → AudioRecord
 *   (AudioPlaybackCapture) → PCM read loop → diagnostics.
 *
 * All capture logic stays entirely native (audio-api.md §23). Flutter only
 * sees the Pigeon wire types used here. Raw PCM never crosses the boundary.
 *
 * The requested capture format is 44100 Hz / stereo / 16-bit PCM, matching
 * Google's official AudioPlaybackCapture sample (the most battle-tested
 * configuration). The actual negotiated format is discovered from the
 * running AudioRecord and reported in the metadata, per audio-api.md §6/§18.
 */
class AudioCaptureEngine(
    private val context: Context,
    private val scope: CoroutineScope,
    private val helper: MediaProjectionHelper,
    private val stateMachine: CaptureStateMachine,
    /** State transitions surfaced to Flutter (must be main-dispatcher safe). */
    private val notifyState: suspend (state: String, metadata: CaptureMetadata?) -> Unit,
    /** Errors surfaced to Flutter (must be main-dispatcher safe). */
    private val notifyError: suspend (code: String, message: String) -> Unit,
    /** Frame arrival stats surfaced to Flutter (must be main-dispatcher safe). */
    private val notifyFrameStats: suspend (stats: FrameArrivalStats) -> Unit,
    /** Notification content updates (must be main-dispatcher safe). */
    private val notifyNotificationUpdate: suspend (isReceivingAudio: Boolean, isSilent: Boolean) -> Unit,
    /** Optional callback for forwarding raw PCM frames to transport layer (Phase 8). */
    private val onFrameCaptured: ((ByteArray, Int, Long) -> Unit)? = null,
) {
    private val TAG = "AudioCaptureEngine"

    private val isRunning = AtomicBoolean(false)
    private var readJob: Job? = null
    private var audioRecord: AudioRecord? = null
    private var mediaProjection: MediaProjection? = null
    private var captureDiagJob: Job? = null
    private val generationCounter = AtomicLong(0)
    @Volatile private var currentMetadata: CaptureMetadata? = null

    // --- Diagnostic counters for BUG #3 pipeline tracing ---
    private val framesCaptured = AtomicLong(0)
    private val bytesCaptured = AtomicLong(0)
    private val framesForwardedToTransport = AtomicLong(0)
    private val lastFrameTimestampNanos = AtomicLong(0)

    // --- Phase 12: Capture timestamp diagnostics ---
    // Circular buffer for capture timestamp samples (PCM read completion + AudioRecord.getTimestamp())
    private val CAPTURE_DIAG_CAPACITY = 50
    private val captureDiagFrames = Array<CaptureTimestampDiag?>(CAPTURE_DIAG_CAPACITY) { null }
    private var captureDiagHead = 0
    private val captureDiagCount = AtomicLong(0)

    data class CaptureTimestampDiag(
        val sequence: Long,
        val pcmReadCompletionTimestampNs: Long,
        val audioRecordFramePosition: Long,
        val audioRecordTimestampNs: Long,
        val audioRecordTimestampAvailable: Boolean,
        val audioRecordTimebase: Int,
        val clockDomainAligned: Boolean
    )

    private val diagnostics = CaptureDiagnostics(scope) { stats ->
        scope.launch {
            notifyFrameStats(stats)
            notifyNotificationUpdate(stats.isReceivingAudio, stats.isSilent)
        }
    }

    /** Fires when MediaProjection is revoked mid-capture (system UI or policy). */
    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.w(TAG, "MediaProjection stopped mid-capture (revoked)")
            projectionRevoked?.complete(Unit)
        }
    }

    @Volatile private var projectionRevoked: CompletableDeferred<Unit>? = null

    /**
     * Start a capture session. Returns the Pigeon wire result directly.
     * Must only be called from PERMISSION_GRANTED (audio-api.md §10).
     */
    suspend fun start(): CaptureResult {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val error = CaptureError(
                CaptureErrorClassifier.CAPTURE_UNSUPPORTED,
                "AudioPlaybackCapture requires Android 10 (API 29); this device runs " +
                    "API ${Build.VERSION.SDK_INT}",
            )
            return CaptureResult(success = false, metadata = null, error = error)
        }

        if (!stateMachine.canStartCapture()) {
            // audio-api.md §27: starting while already capturing (or without
            // permission) is an error, never a silent restart.
            val error = CaptureError(
                CaptureErrorClassifier.CAPTURE_START_FAILED,
                "Cannot start capture from state ${stateMachine.state()} " +
                    "(startCapture requires PERMISSION_GRANTED from requestCapturePermission)",
            )
            return CaptureResult(success = false, metadata = null, error = error)
        }

        val grant = helper.consumeGrant()
        if (grant == null) {
            val error = CaptureError(
                CaptureErrorClassifier.PERMISSION_DENIED,
                "No MediaProjection consent grant available; requestCapturePermission() " +
                    "must return GRANTED before startCapture()",
            )
            return CaptureResult(success = false, metadata = null, error = error)
        }

        val generation = generationCounter.incrementAndGet()
        val sessionId = UUID.randomUUID().toString()

        return try {
            startInternal(grant, sessionId, generation)
        } catch (e: Exception) {
            val classified = CaptureErrorClassifier.classify(e)
            Log.e(TAG, "Capture start failed: ${classified.message}", e)
            cleanupCaptureResources()
            stateMachine.fail(classified.code, classified.message)
            notifyError(classified.code, classified.message)
            notifyState(CaptureSessionState.FAILED.name, null)
            CaptureResult(
                success = false,
                metadata = null,
                error = CaptureError(classified.code, classified.message),
            )
        }
    }

    private suspend fun startInternal(
        grant: MediaProjectionHelper.Grant,
        sessionId: String,
        generation: Long,
    ): CaptureResult {
        // 1. Foreground service MUST be foreground before getMediaProjection()
        //    on Android 14+ (throws otherwise).
        val foregroundStarted = AudioCaptureService.startAwaitingForeground(context)
        if (!foregroundStarted) {
            throw IllegalStateException(
                "mediaProjection-type foreground service failed to enter foreground",
            )
        }

        // 2. Create MediaProjection from the one-shot consent grant.
        projectionRevoked = CompletableDeferred()
        val projection = helper.createProjection(grant)
        projection.registerCallback(projectionCallback, Handler(Looper.getMainLooper()))
        mediaProjection = projection

        // Wire the notification's Stop action to a clean engine stop.
        AudioCaptureService.setStopListener { scope.launch { stop() } }

        // 3. Build the AudioPlaybackCapture AudioRecord.
        val captureConfig = AudioPlaybackCaptureConfiguration.Builder(projection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val audioFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(CAPTURE_SAMPLE_RATE_HZ)
            .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
            .build()

        val minBufferBytes = AudioRecord.getMinBufferSize(
            CAPTURE_SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_IN_STEREO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferBytes = maxOf(minBufferBytes, MIN_FALLBACK_BUFFER_BYTES) * BUFFER_SCALE

        val record = AudioRecord.Builder()
            .setAudioFormat(audioFormat)
            .setAudioPlaybackCaptureConfig(captureConfig)
            .setBufferSizeInBytes(bufferBytes)
            .build()

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("AudioRecord failed to initialize (state=${record.state})")
        }

        // 4. Start recording and discover the actual negotiated format.
        record.startRecording()
        if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
            record.release()
            throw IllegalStateException("AudioRecord failed to enter recording state")
        }

        audioRecord = record

        val sampleRate = record.sampleRate
        val channelCount = record.channelCount
        val encodingName = when (record.audioFormat) {
            AudioFormat.ENCODING_PCM_16BIT -> "PCM_16BIT"
            AudioFormat.ENCODING_PCM_FLOAT -> "PCM_FLOAT"
            AudioFormat.ENCODING_PCM_8BIT -> "PCM_8BIT"
            else -> "ENCODING_${record.audioFormat}"
        }
        diagnostics.reset()
        diagnostics.setFormat(sampleRate, channelCount, encodingName)
        diagnostics.start()

        val metadata = CaptureMetadata(
            sessionId = sessionId,
            generation = generation,
            sampleRate = sampleRate.toLong(),
            channelCount = channelCount.toLong(),
            startedAtNanos = SystemClock.elapsedRealtimeNanos(),
        )
        currentMetadata = metadata

        // 5. Transition to CAPTURING and start the native read loop.
        check(stateMachine.startCapture()) {
            "State machine refused CAPTURING transition from ${stateMachine.state()}"
        }
        notifyState(CaptureSessionState.CAPTURING.name, metadata)

        isRunning.set(true)
        framesCaptured.set(0)
        bytesCaptured.set(0)
        framesForwardedToTransport.set(0)
        lastFrameTimestampNanos.set(0)
        readJob = scope.launch(Dispatchers.IO) { readLoop(record, bufferBytes) }
        captureDiagJob = scope.launch(Dispatchers.IO) { captureDiagnosticsReporter() }

        Log.i(
            TAG,
            "Capture started: sessionId=$sessionId generation=$generation " +
                "format=${sampleRate}Hz/$channelCount/ch/$encodingName buffer=${bufferBytes}B",
        )
        return CaptureResult(success = true, metadata = metadata, error = null)
    }

    /**
     * Native PCM read loop. This is the proof-of-capture for Phase 5: frames
     * are consumed natively, counted, and characterized — never shipped to
     * Dart.
     */
    private suspend fun readLoop(record: AudioRecord, bufferBytes: Int) {
        val readBuffer = ByteArray(bufferBytes.coerceAtLeast(MIN_READ_BYTES))
        val audioTimestamp = AudioTimestamp()
        var localSequence = 0L
        try {
            while (isRunning.get()) {
                val readBytes = record.read(readBuffer, 0, readBuffer.size)
                when {
                    readBytes > 0 -> {
                        diagnostics.recordFrame(readBuffer, readBytes)
                        framesCaptured.incrementAndGet()
                        bytesCaptured.addAndGet(readBytes.toLong())

                        // Phase 12: Capture timestamp probing
                        // T1: PCM read completion timestamp (existing behavior)
                        val pcmReadCompletionTimestamp = SystemClock.elapsedRealtimeNanos()
                        lastFrameTimestampNanos.set(pcmReadCompletionTimestamp)

                        // AudioRecord.getTimestamp() probe
                        var audioRecordFramePosition: Long = -1
                        var audioRecordTimestampNs: Long = -1
                        var audioRecordTimestampAvailable = false
                        var audioRecordTimebase = AudioTimestamp.TIMEBASE_MONOTONIC
                        var clockDomainAligned = false

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            var timebase = AudioTimestamp.TIMEBASE_MONOTONIC
                            var success = false
                            // Use reflection to call parameterless getTimestamp() to avoid overload resolution issues
                            // AudioRecord.getTimestamp(AudioTimestamp) exists on API 24+, returns Int on 24-28, Boolean on 29+
                            try {
                                val method = AudioRecord::class.java.getMethod("getTimestamp", AudioTimestamp::class.java)
                                val result = method.invoke(record, audioTimestamp)
                                success = when (result) {
                                    is Boolean -> result
                                    is Int -> result == AudioRecord.SUCCESS
                                    else -> false
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "AudioRecord.getTimestamp reflection failed", e)
                                success = false
                            }
                            if (success) {
                                audioRecordFramePosition = audioTimestamp.framePosition
                                audioRecordTimestampNs = audioTimestamp.nanoTime
                                audioRecordTimestampAvailable = true
                                // Parameterless getTimestamp() uses MONOTONIC timebase on all API levels
                                // Not aligned with elapsedRealtimeNanos() (which equals BOOTTIME)
                                clockDomainAligned = false
                            }
                            audioRecordTimebase = timebase
                        }

                        // Store in circular buffer
                        val idx = captureDiagHead % CAPTURE_DIAG_CAPACITY
                        captureDiagFrames[idx] = CaptureTimestampDiag(
                            sequence = localSequence,
                            pcmReadCompletionTimestampNs = pcmReadCompletionTimestamp,
                            audioRecordFramePosition = audioRecordFramePosition,
                            audioRecordTimestampNs = audioRecordTimestampNs,
                            audioRecordTimestampAvailable = audioRecordTimestampAvailable,
                            audioRecordTimebase = audioRecordTimebase,
                            clockDomainAligned = clockDomainAligned
                        )
                        captureDiagHead++
                        captureDiagCount.incrementAndGet()
                        localSequence++

                        // Forward frame to transport layer (Phase 8)
                        onFrameCaptured?.invoke(readBuffer, readBytes, pcmReadCompletionTimestamp)
                        framesForwardedToTransport.incrementAndGet()
                        // NOTE: No SOURCE_APP_BLOCKED heuristic here.
                        // "No audio currently playing" is a normal, expected state —
                        // not an error. The isReceivingAudio/isSilent flags in FrameArrivalStats
                        // communicate this to Flutter/UI. SOURCE_APP_BLOCKED should
                        // only fire if Android explicitly signals a policy-based
                        // capture rejection (not currently available via public API).
                    }
                    readBytes == 0 -> {
                        // Blocking read returns 0 when the record is stopped —
                        // normal shutdown path.
                        break
                    }
                    else -> {
                        handleUnexpectedEnd(
                            CaptureErrorClassifier.classifyReadError(readBytes),
                        )
                        return
                    }
                }

                // MediaProjection revoked mid-capture (system/user) → distinct
                // CAPTURE_INTERRUPTED.
                if (isRunning.get() && projectionRevoked?.isCompleted == true) {
                    handleUnexpectedEnd(CaptureErrorClassifier.projectionRevoked())
                    return
                }
            }
        } catch (e: Exception) {
            val classified = CaptureErrorClassifier.classify(e)
            Log.e(TAG, "Read loop failed: ${classified.message}", e)
            handleUnexpectedEnd(classified)
            return
        }

        // Loop exited without an error. If isRunning is still true, capture
        // ended without stopCapture() being called — surface as interruption.
        if (isRunning.getAndSet(false)) {
            handleUnexpectedEnd(
                CaptureErrorClassifier.classifyReadError(AudioRecord.ERROR_INVALID_OPERATION),
            )
        }
    }

    /** Surface a capture interruption: error + CAPTURING → FAILED. */
    private suspend fun handleUnexpectedEnd(classified: CaptureErrorClassifier.ClassifiedError) {
        isRunning.set(false)
        cleanupCaptureResources()
        stateMachine.fail(classified.code, classified.message)
        notifyError(classified.code, classified.message)
        notifyState(CaptureSessionState.FAILED.name, null)
    }

    /**
     * Stop the capture session cleanly (audio-api.md §11). Safe to call even
     * when nothing is active. Releases the MediaProjection session and stops
     * the foreground service.
     */
    suspend fun stop() {
        val wasActive = stateMachine.state() == CaptureSessionState.CAPTURING ||
            stateMachine.state() == CaptureSessionState.PERMISSION_GRANTED

        isRunning.set(false)

        // Discard any consent grant not consumed by a start; Android 14
        // consent tokens are single-use and must not be reused later.
        helper.discardGrant()

        // Unblock the blocking read; it returns 0 shortly after stop().
        audioRecord?.stop()

        // Give the read loop a moment to observe the stop before cancelling.
        withTimeoutOrNull(READ_LOOP_JOIN_TIMEOUT_MS) {
            readJob?.join()
        }
        readJob?.cancel()
        readJob = null

        cleanupCaptureResources()

        if (wasActive) {
            val newState = stateMachine.stopCapture()
            currentMetadata = null
            notifyState(newState.name, null)
        }
    }

    /** Release record + projection + service. Idempotent. */
    private fun cleanupCaptureResources() {
        diagnostics.stop()
        captureDiagJob?.cancel()
        captureDiagJob = null
        runCatching { audioRecord?.stop() }
        runCatching { audioRecord?.release() }
        audioRecord = null
        mediaProjection?.let { projection ->
            runCatching { projection.unregisterCallback(projectionCallback) }
            runCatching { projection.stop() }
        }
        mediaProjection = null
        AudioCaptureService.setStopListener(null)
        AudioCaptureService.stop(context)
    }

    /** Periodic diagnostic reporter for pipeline tracing (BUG #3 + Phase 12). */
    private suspend fun captureDiagnosticsReporter() {
        try {
            while (isRunning.get()) {
                kotlinx.coroutines.delay(2000)
                val now = SystemClock.elapsedRealtimeNanos()
                val lastFrameAgeMs = if (lastFrameTimestampNanos.get() > 0) {
                    (now - lastFrameTimestampNanos.get()) / 1_000_000
                } else -1L

                // Phase 12: Capture timestamp diagnostics
                var availableCount = 0L
                var alignedCount = 0L
                var deltaSum = 0L
                var deltaMin = Long.MAX_VALUE
                var deltaMax = Long.MIN_VALUE
                var latestDiag: CaptureTimestampDiag? = null
                var latestIdx = -1

                val count = captureDiagCount.get().toInt().coerceAtMost(CAPTURE_DIAG_CAPACITY)
                for (i in 0 until count) {
                    val idx = (captureDiagHead - count + i) % CAPTURE_DIAG_CAPACITY
                    val diag = captureDiagFrames[idx]
                    diag?.let {
                        if (it.audioRecordTimestampAvailable) {
                            availableCount++
                            if (it.clockDomainAligned) {
                                alignedCount++
                                // Only compute delta when clock domains are aligned
                                val delta = it.audioRecordTimestampNs - it.pcmReadCompletionTimestampNs
                                deltaSum += delta
                                if (delta < deltaMin) deltaMin = delta
                                if (delta > deltaMax) deltaMax = delta
                            }
                        }
                        if (it.sequence > (latestDiag?.sequence ?: -1L)) {
                            latestDiag = it
                            latestIdx = idx
                        }
                    }
                }

                val deltaAvg = if (alignedCount > 0) deltaSum / alignedCount else 0L
                val deltaMinStr = if (deltaMin != Long.MAX_VALUE) deltaMin else "N/A"
                val deltaMaxStr = if (deltaMax != Long.MIN_VALUE) deltaMax else "N/A"
                val timebaseStr = latestDiag?.audioRecordTimebase?.let {
                    when (it) {
                        AudioTimestamp.TIMEBASE_BOOTTIME -> "BOOTTIME"
                        AudioTimestamp.TIMEBASE_MONOTONIC -> "MONOTONIC"
                        else -> "UNKNOWN($it)"
                    }
                } ?: "N/A"
                val alignedStr = latestDiag?.clockDomainAligned?.let { if (it) "ALIGNED" else "UNALIGNED" } ?: "N/A"
                val latestStr = latestDiag?.let {
                    "seq=${it.sequence} pcmRead=${it.pcmReadCompletionTimestampNs} " +
                    "arFrame=${it.audioRecordFramePosition} arTs=${it.audioRecordTimestampNs} " +
                    "avail=${it.audioRecordTimestampAvailable} tb=$timebaseStr aligned=$alignedStr " +
                    "delta=${if (it.clockDomainAligned) (it.audioRecordTimestampNs - it.pcmReadCompletionTimestampNs) else "N/A"}"
                } ?: "none"

                Log.i(
                    TAG,
                    "[DIAG] Capture: frames=${framesCaptured.get()} bytes=${bytesCaptured.get()} " +
                        "forwarded=${framesForwardedToTransport.get()} lastFrameAgeMs=$lastFrameAgeMs " +
                        "captureDiag: count=$count avail=$availableCount aligned=$alignedCount " +
                        "deltaAvgNs=$deltaAvg deltaMin=$deltaMinStr deltaMax=$deltaMaxStr " +
                        "latest=[$latestStr]"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Capture diagnostics reporter failed", e)
        }
    }

    /** Current metadata for getCaptureState(); null unless CAPTURING. */
    fun currentMetadata(): CaptureMetadata? =
        if (stateMachine.isCapturing()) currentMetadata else null

    private fun ByteArray.allZero(length: Int): Boolean {
        for (i in 0 until length) {
            if (this[i].toInt() != 0) return false
        }
        return true
    }

    companion object {
        /**
         * 44100 Hz stereo 16-bit — matches the official Android
         * AudioPlaybackCapture sample; the most widely supported
         * configuration across Android devices.
         */
        const val CAPTURE_SAMPLE_RATE_HZ = 44_100
        private const val MIN_FALLBACK_BUFFER_BYTES = 2_048
        private const val BUFFER_SCALE = 2
        private const val MIN_READ_BYTES = 2_048
        private const val READ_LOOP_JOIN_TIMEOUT_MS = 1_000L
    }
}
