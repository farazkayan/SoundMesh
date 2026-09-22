package com.soundmesh.soundmesh.output

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.soundmesh.soundmesh.AudioOutputPlatform
import com.soundmesh.soundmesh.OutputState
import com.soundmesh.soundmesh.transport.AudioPacket
import com.soundmesh.soundmesh.transport.AudioReceiveEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

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
) : AudioOutputPlatform {
    private val TAG = "AudioOutputEngine"

    private val isOutputting = AtomicBoolean(false)
    private val isInitialized = AtomicBoolean(false)
    private var currentSampleRate = 0
    private var currentChannelCount = 0
    private var currentGeneration = 0L
    private var drainJob: Job? = null
    private var audioTrack: AudioTrack? = null
    private var receiveEngine: AudioReceiveEngine? = null

    // Frame timing: 20ms per frame at 44.1kHz stereo 16-bit = 3528 bytes
    private val frameSizeBytes = AtomicLong(0)
    private val frameDurationMs = 20L

    // Audio route monitoring
    private var audioManager: AudioManager? = null
    private var lastKnownDeviceId = -1

    // Diagnostic counters
    private val packetsWritten = AtomicLong(0)
    private val bytesWritten = AtomicLong(0)
    private val writeErrors = AtomicLong(0)
    private val underrunsReported = AtomicLong(0)
    private var diagJob: Job? = null

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
    fun onStreamInfo(generation: Long, sampleRate: Int, channelCount: Int) {
        Log.i(TAG, "onStreamInfo called: generation=$generation, currentGeneration=$currentGeneration, sampleRate=$sampleRate, channelCount=$channelCount")
        if (generation > currentGeneration) {
            Log.i(TAG, "New stream generation for output: $generation (was $currentGeneration), format=${sampleRate}Hz/${channelCount}ch")
            reset()
            currentGeneration = generation
            currentSampleRate = sampleRate
            currentChannelCount = channelCount

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

            // Calculate buffer size - 20ms frames, target ~200ms buffer
            val frameSize = (sampleRate * channelCount * 2 * 20 / 1000) // bytes per 20ms frame
            val bufferSize = frameSize * 10 // ~200ms buffer
            val minBufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, AudioFormat.ENCODING_PCM_16BIT)
            val finalBufferSize = maxOf(bufferSize, minBufferSize * 2)

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
        while (!bufferReady && waitCount2 < 50 && isOutputting.get()) {
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

        // Start the frame drain coroutine
        isOutputting.set(true)
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
     */
    private suspend fun drainFrames() {
        try {
            while (isOutputting.get()) {
                val packet = receiveEngine?.pollNextPacket()

                if (packet == null) {
                    // Underrun - no packet available yet
                    underrunsReported.incrementAndGet()
                    // Wait for next frame period before polling again
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

                // Small delay to avoid busy-waiting when packets arrive faster than we can write
                // This also provides backpressure to the jitter buffer
                if (written == packet.payload.size) {
                    delay(1) // Minimal yield when keeping up
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Drain loop failed", e)
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_FAILURE", "Drain loop failed: ${e.message}")
            }
        }
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
        isOutputting.set(false)
        isInitialized.set(false)
        currentGeneration = 0
        currentSampleRate = 0
        currentChannelCount = 0
        frameSizeBytes.set(0)
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
    }

    /** Periodic diagnostic reporter for pipeline tracing. */
    private suspend fun diagnosticsReporter() {
        try {
            while (isOutputting.get()) {
                delay(2000)
                val bufferDepth = receiveEngine?.getBufferDepth() ?: -1
                val bufferDepthMs = receiveEngine?.getBufferDepthMs() ?: -1
                Log.i(
                    TAG,
                    "[DIAG] AudioOutput: packetsWritten=${packetsWritten.get()} " +
                        "bytesWritten=${bytesWritten.get()} writeErrors=${writeErrors.get()} " +
                        "underruns=${underrunsReported.get()} " +
                        "bufferDepth=$bufferDepth bufferDepthMs=$bufferDepthMs " +
                        "playState=${audioTrack?.playState ?: -1}"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Diagnostics reporter failed", e)
        }
    }
}