package com.soundmesh.soundmesh.capture

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.soundmesh.soundmesh.CaptureError
import com.soundmesh.soundmesh.CaptureMetadata
import com.soundmesh.soundmesh.CaptureResult
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
    private val diagnostics: CaptureDiagnostics,
    /** State transitions surfaced to Flutter (must be main-dispatcher safe). */
    private val notifyState: suspend (state: String, metadata: CaptureMetadata?) -> Unit,
    /** Errors surfaced to Flutter (must be main-dispatcher safe). */
    private val notifyError: suspend (code: String, message: String) -> Unit,
) {
    private val TAG = "AudioCaptureEngine"

    private val isRunning = AtomicBoolean(false)
    private var readJob: Job? = null
    private var audioRecord: AudioRecord? = null
    private var mediaProjection: MediaProjection? = null
    private val generationCounter = AtomicLong(0)
    @Volatile private var currentMetadata: CaptureMetadata? = null
    private val silenceDetector = SilenceDetector()

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
        readJob = scope.launch(Dispatchers.IO) { readLoop(record, bufferBytes) }

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
        try {
            while (isRunning.get()) {
                val readBytes = record.read(readBuffer, 0, readBuffer.size)
                when {
                    readBytes > 0 -> {
                        val silent = readBuffer.allZero(readBytes)
                        diagnostics.recordFrame(readBytes, silent)
                        if (silenceDetector.observe(readBuffer, readBytes)) {
                            // Distinct SOURCE_APP_BLOCKED signal. Deliberately
                            // NOT tearing down the capture: sustained silence is
                            // ambiguous (blocked source vs paused source,
                            // audio-api.md §40.2). Keep capturing so a paused
                            // source self-corrects; the experiment table
                            // disambiguates per app.
                            val message = "Sustained digital silence while frames keep " +
                                "arriving — source app likely blocked capture " +
                                "(ALLOW_CAPTURE_BY policy) or is paused/muted"
                            Log.w(TAG, "SOURCE_APP_BLOCKED heuristic fired: $message")
                            notifyError(CaptureErrorClassifier.SOURCE_APP_BLOCKED, message)
                        }
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
        runCatching { audioRecord?.stop() }
        runCatching { audioRecord?.release() }
        audioRecord = null
        mediaProjection?.let { projection ->
            runCatching { projection.unregisterCallback(projectionCallback) }
            runCatching { projection.stop() }
        }
        mediaProjection = null
        silenceDetector.reset()
        AudioCaptureService.setStopListener(null)
        AudioCaptureService.stop(context)
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
