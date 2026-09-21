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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.ClosedReceiveChannelException
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean

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
    private var writeThread: Thread? = null
    private var isWriteThreadRunning = AtomicBoolean(false)

    // Channel for frames from receive engine to output engine
    private val frameChannel = Channel<AudioPacket>(capacity = 100)

    // Audio route monitoring
    private var audioManager: AudioManager? = null
    private var lastKnownDeviceId = -1

    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager?
    }

    /**
     * Initialize output engine with format from stream info.
     * Called when AUDIO_STREAM_INFO is received with a new generation.
     */
    fun onStreamInfo(generation: Long, sampleRate: Int, channelCount: Int) {
        if (generation > currentGeneration) {
            Log.i(TAG, "New stream generation for output: $generation (was $currentGeneration), format=${sampleRate}Hz/${channelCount}ch")
            reset()
            currentGeneration = generation
            currentSampleRate = sampleRate
            currentChannelCount = channelCount

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
        if (generation != currentGeneration) {
            Log.w(TAG, "Stream start for wrong generation: $generation (current: $currentGeneration)")
            return
        }
        if (!isInitialized.get()) {
            Log.w(TAG, "Cannot start output: not initialized")
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_NOT_READY", "Output engine not initialized")
            }
            return
        }
        if (isOutputting.get()) {
            Log.w(TAG, "Output already running")
            return
        }

        // Start the frame drain coroutine
        drainJob = scope.launch(Dispatchers.IO) { drainFrames() }

        // Start AudioTrack
        audioTrack?.play()
        isOutputting.set(true)
        isWriteThreadRunning.set(true)

        Log.i(TAG, "Output started for generation $generation")
        scope.launch {
            notifyOutputState("OUTPUT_STARTED", null, null)
        }
    }

    /**
     * Stop output (called on AUDIO_STREAM_STOP or generation change).
     */
    suspend fun onStreamStop(generation: Long) {
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

        isWriteThreadRunning.set(false)
        writeThread?.interrupt()
        writeThread?.join(1000)
        writeThread = null

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
     * Feed a packet from AudioReceiveEngine into the output engine.
     * Called by the receive engine when a packet is ready for playback.
     */
    fun onAudioPacket(packet: AudioPacket) {
        if (!isOutputting.get()) return

        // Non-blocking send to channel
        scope.launch {
            try {
                frameChannel.send(packet)
            } catch (e: ClosedReceiveChannelException) {
                // Channel closed, output stopped
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enqueue output frame seq=${packet.sequenceNumber}", e)
            }
        }
    }

    /**
     * Drain frames from channel and write to AudioTrack.
     * Runs on IO dispatcher.
     */
    private suspend fun drainFrames() {
        try {
            for (packet in frameChannel) {
                if (!isOutputting.get()) break

                val written = writeToAudioTrack(packet)

                if (written < packet.payload.size) {
                    Log.w(TAG, "Partial write: $written/${packet.payload.size} bytes, seq=${packet.sequenceNumber}")
                    scope.launch {
                        notifyOutputState("OUTPUT_UNDERRUN", "OUTPUT_UNDERRUN", "Output buffer underrun (partial write)")
                    }
                }
            }
        } catch (e: ClosedReceiveChannelException) {
            // Normal shutdown
        } catch (e: Exception) {
            Log.e(TAG, "Drain loop failed", e)
            scope.launch {
                notifyOutputState("ERROR", "OUTPUT_FAILURE", "Drain loop failed: ${e.message}")
            }
        }
    }

    private fun writeToAudioTrack(packet: AudioPacket): Int {
        val track = audioTrack ?: return 0
        if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
            return 0
        }

        var offset = 0
        val totalBytes = packet.payload.size
        while (offset < totalBytes && isOutputting.get()) {
            val bytesToWrite = minOf(totalBytes - offset, 4096)
            val written = track.write(packet.payload, offset, bytesToWrite, AudioTrack.WRITE_BLOCKING)
            if (written < 0) {
                Log.e(TAG, "AudioTrack write error: $written")
                return offset
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
        isOutputting.set(false)
        isInitialized.set(false)
        currentGeneration = 0
        currentSampleRate = 0
        currentChannelCount = 0
        drainJob?.cancel()
        drainJob = null

        isWriteThreadRunning.set(false)
        writeThread?.interrupt()
        writeThread = null

        audioTrack?.stop()
        audioTrack?.flush()
        audioTrack?.release()
        audioTrack = null

        try {
            frameChannel.close()
        } catch (e: Exception) {
            // Ignore
        }
    }
}