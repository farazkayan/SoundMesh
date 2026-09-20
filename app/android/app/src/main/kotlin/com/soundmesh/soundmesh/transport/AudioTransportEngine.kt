package com.soundmesh.soundmesh.transport

import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.soundmesh.soundmesh.CaptureMetadata
import com.soundmesh.soundmesh.StreamingMetadata
import com.soundmesh.soundmesh.StreamingState
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.ClosedReceiveChannelException
import kotlinx.coroutines.channels.ReceiveChannel
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Host-side audio transport engine.
 *
 * Consumes PCM frames from AudioCaptureEngine, packetizes into ~20ms chunks,
 * assigns sequence numbers and timestamps, and sends via the existing
 * NetworkHostPlatform connection (messageType = "AUDIO_PACKET").
 *
 * All transport logic stays native; only aggregate state crosses to Flutter.
 */
class AudioTransportEngine(
    private val context: Context,
    private val scope: CoroutineScope,
    /** Send a protocol message over the existing TCP connection. */
    private val sendProtocolMessage: (String) -> Boolean,
    /** Notify Flutter of stream state changes (STREAMING/STOPPED/FAILED). */
    private val notifyStreamState: suspend (state: String, metadata: StreamingMetadata?) -> Unit,
    /** Notify Flutter of stream errors. */
    private val notifyStreamError: suspend (code: String, message: String) -> Unit,
) {
    private val TAG = "AudioTransportEngine"

    companion object {
        // ~20ms frame at 44.1kHz stereo 16-bit = 44100 * 2 * 2 * 0.02 = 3528 bytes
        const val TARGET_FRAME_BYTES = 3528
        const val SAMPLES_PER_FRAME = TARGET_FRAME_BYTES / 2 / 2 // 16-bit stereo = 2 bytes * 2 channels
    }

    private val isStreaming = AtomicBoolean(false)
    private var currentGeneration = 0L
    private var sequenceNumber = AtomicInteger(0)
    private var currentSampleRate = 0
    private var currentChannelCount = 0
    private var sessionId: String? = null

    // Accumulator for partial frames
    private val frameAccumulator = java.io.ByteArrayOutputStream()
    private var pendingSendJob: Job? = null

    // Channel for sending packets from capture thread to network thread
    private val packetChannel = Channel<AudioPacket>(capacity = 50)

    /**
     * Start streaming for a new capture session.
     * Must be called after successful capture start with same generation.
     */
    suspend fun startStreaming(captureMetadata: CaptureMetadata) {
        if (isStreaming.get()) {
            Log.w(TAG, "startStreaming called but already streaming")
            return
        }

        currentGeneration = captureMetadata.generation
        sequenceNumber.set(0)
        currentSampleRate = captureMetadata.sampleRate.toInt()
        currentChannelCount = captureMetadata.channelCount.toInt()
        sessionId = captureMetadata.sessionId
        frameAccumulator.reset()

        val metadata = StreamingMetadata(
            sessionId = captureMetadata.sessionId,
            generation = captureMetadata.generation,
            sampleRate = captureMetadata.sampleRate,
            channelCount = captureMetadata.channelCount,
            startedAtNanos = SystemClock.elapsedRealtimeNanos(),
        )

        isStreaming.set(true)

        // Start the packet sender coroutine
        pendingSendJob = scope.launch(Dispatchers.IO) { packetSender() }

        // Send AUDIO_STREAM_INFO message with format info
        sendStreamInfo(metadata)

        // Send AUDIO_STREAM_START to signal participants
        sendStreamStart(metadata)

        notifyStreamState("STREAMING", metadata)
        Log.i(TAG, "Streaming started: generation=${captureMetadata.generation} format=${currentSampleRate}Hz/${currentChannelCount}ch")
    }

    /**
     * Stop streaming cleanly.
     */
    suspend fun stopStreaming() {
        if (!isStreaming.getAndSet(false)) {
            Log.d(TAG, "stopStreaming called but not streaming")
            return
        }

        // Send AUDIO_STREAM_STOP
        sessionId?.let { sendStreamStop(it, currentGeneration) }

        // Cancel sender and drain channel
        pendingSendJob?.cancel()
        try {
            packetChannel.close()
        } catch (e: Exception) {
            // Ignore
        }

        notifyStreamState("STOPPED", null)
        Log.i(TAG, "Streaming stopped")
    }

    /**
     * Called by AudioCaptureEngine for each PCM frame read.
     * Accumulates bytes until we have a full ~20ms packet, then enqueues for sending.
     */
    fun onPcmFrame(pcmData: ByteArray, byteCount: Int, captureTimestampNanos: Long) {
        if (!isStreaming.get()) return

        frameAccumulator.write(pcmData, 0, byteCount)

        // Emit full frames
        while (frameAccumulator.size() >= TARGET_FRAME_BYTES) {
            val frameBytes = ByteArray(TARGET_FRAME_BYTES)
            frameAccumulator.reset() // This doesn't work as expected - need to read from buffer
            // Re-read the accumulated data
            val allData = frameAccumulator.toByteArray()
            frameAccumulator.reset()
            if (allData.size >= TARGET_FRAME_BYTES) {
                System.arraycopy(allData, 0, frameBytes, 0, TARGET_FRAME_BYTES)
                // Put remaining back
                if (allData.size > TARGET_FRAME_BYTES) {
                    frameAccumulator.write(allData, TARGET_FRAME_BYTES, allData.size - TARGET_FRAME_BYTES)
                }

                val seq = sequenceNumber.getAndIncrement()
                val packet = AudioPacket(
                    streamGeneration = currentGeneration,
                    sequenceNumber = seq,
                    captureTimestampNanos = captureTimestampNanos,
                    sampleRate = currentSampleRate,
                    channelCount = currentChannelCount,
                    payload = frameBytes,
                )

                // Non-blocking send to channel
                scope.launch {
                    try {
                        packetChannel.send(packet)
                    } catch (e: ClosedReceiveChannelException) {
                        // Channel closed, streaming stopped
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to enqueue packet", e)
                    }
                }
            } else {
                // Not enough data, put it back
                frameAccumulator.write(allData)
                break
            }
        }
    }

    /**
     * Coroutine that reads packets from channel and sends over network.
     */
    private suspend fun packetSender() {
        try {
            for (packet in packetChannel) {
                if (!isStreaming.get()) break

                val wireBytes = AudioPacket.toByteArray(packet)
                // Wrap in our protocol envelope with messageType = "AUDIO_PACKET"
                val json = StringBuilder()
                json.append("{")
                json.append("\"protocolVersion\":1,")
                json.append("\"messageId\":\"${java.util.UUID.randomUUID()}\",")
                json.append("\"messageType\":\"AUDIO_PACKET\",")
                json.append("\"sessionId\":\"$sessionId\",")
                json.append("\"senderId\":\"host\",")
                json.append("\"generation\":${packet.streamGeneration},")
                json.append("\"timestamp\":${System.currentTimeMillis()},")
                json.append("\"payload\":{")
                json.append("\"data\":\"${android.util.Base64.encodeToString(wireBytes, android.util.Base64.NO_WRAP)}\",")
                json.append("\"sequence\":${packet.sequenceNumber},")
                json.append("\"captureTimestamp\":${packet.captureTimestampNanos}")
                json.append("}}")

                val sent = sendProtocolMessage(json.toString())
                if (!sent) {
                    Log.w(TAG, "Failed to send audio packet seq=${packet.sequenceNumber}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Packet sender failed", e)
            if (isStreaming.getAndSet(false)) {
                notifyStreamError("TRANSPORT_FAILED", "Audio packet sender failed: ${e.message}")
                notifyStreamState("FAILED", null)
            }
        }
    }

    private fun sendStreamInfo(metadata: StreamingMetadata) {
        val json = StringBuilder()
        json.append("{")
        json.append("\"protocolVersion\":1,")
        json.append("\"messageId\":\"${java.util.UUID.randomUUID()}\",")
        json.append("\"messageType\":\"AUDIO_STREAM_INFO\",")
        json.append("\"sessionId\":\"${metadata.sessionId}\",")
        json.append("\"senderId\":\"host\",")
        json.append("\"generation\":${metadata.generation},")
        json.append("\"timestamp\":${System.currentTimeMillis()},")
        json.append("\"payload\":{")
        json.append("\"sampleRate\":${metadata.sampleRate},")
        json.append("\"channelCount\":${metadata.channelCount},")
        json.append("\"startedAtNanos\":${metadata.startedAtNanos}")
        json.append("}}")
        sendProtocolMessage(json.toString())
    }

    private fun sendStreamStart(metadata: StreamingMetadata) {
        val json = StringBuilder()
        json.append("{")
        json.append("\"protocolVersion\":1,")
        json.append("\"messageId\":\"${java.util.UUID.randomUUID()}\",")
        json.append("\"messageType\":\"AUDIO_STREAM_START\",")
        json.append("\"sessionId\":\"${metadata.sessionId}\",")
        json.append("\"senderId\":\"host\",")
        json.append("\"generation\":${metadata.generation},")
        json.append("\"timestamp\":${System.currentTimeMillis()},")
        json.append("\"payload\":{}")
        json.append("}")
        sendProtocolMessage(json.toString())
    }

    private fun sendStreamStop(sessionId: String, generation: Long) {
        val json = StringBuilder()
        json.append("{")
        json.append("\"protocolVersion\":1,")
        json.append("\"messageId\":\"${java.util.UUID.randomUUID()}\",")
        json.append("\"messageType\":\"AUDIO_STREAM_STOP\",")
        json.append("\"sessionId\":\"$sessionId\",")
        json.append("\"senderId\":\"host\",")
        json.append("\"generation\":$generation,")
        json.append("\"timestamp\":${System.currentTimeMillis()},")
        json.append("\"payload\":{}")
        json.append("}")
        sendProtocolMessage(json.toString())
    }

    /** Current streaming state for getStreamingState(). */
    fun getState(): StreamingState {
        return if (isStreaming.get()) {
            val metadata = sessionId?.let {
                StreamingMetadata(
                    sessionId = it,
                    generation = currentGeneration,
                    sampleRate = currentSampleRate.toLong(),
                    channelCount = currentChannelCount.toLong(),
                    startedAtNanos = SystemClock.elapsedRealtimeNanos(),
                )
            }
            StreamingState(state = "STREAMING", metadata = metadata)
        } else {
            StreamingState(state = "IDLE", metadata = null)
        }
    }
}