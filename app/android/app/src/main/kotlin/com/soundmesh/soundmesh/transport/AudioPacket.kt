package com.soundmesh.soundmesh.transport

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Binary packet structure for AUDIO_PACKET message type.
 *
 * Wire format (all integers little-endian):
 *   streamGeneration:  8 bytes (int64)  — matches CaptureMetadata.generation
 *   sequenceNumber:    4 bytes (uint32) — monotonically increasing per generation
 *   captureTimestamp:  8 bytes (int64)  — SystemClock.elapsedRealtimeNanos()
 *   sampleRate:        4 bytes (int32)  — from capture metadata
 *   channelCount:      4 bytes (int32)  — from capture metadata
 *   payload:           variable        — PCM frame data (e.g., 3528 bytes for 20ms @ 44.1kHz stereo 16-bit)
 *
 * Total header size: 28 bytes + payload
 */
data class AudioPacket(
    val streamGeneration: Long,
    val sequenceNumber: Int,
    val captureTimestampNanos: Long,
    val sampleRate: Int,
    val channelCount: Int,
    val payload: ByteArray,
) {
    companion object {
        const val HEADER_SIZE = 28 // 8 + 4 + 8 + 4 + 4

        /**
         * Serialize to byte array (little-endian).
         */
        fun toByteArray(packet: AudioPacket): ByteArray {
            val buffer = ByteBuffer.allocate(HEADER_SIZE + packet.payload.size)
                .order(ByteOrder.LITTLE_ENDIAN)
            buffer.putLong(packet.streamGeneration)
            buffer.putInt(packet.sequenceNumber)
            buffer.putLong(packet.captureTimestampNanos)
            buffer.putInt(packet.sampleRate)
            buffer.putInt(packet.channelCount)
            buffer.put(packet.payload)
            return buffer.array()
        }

        /**
         * Deserialize from byte array (little-endian).
         * Returns null if data is too short for header.
         */
        fun fromByteArray(data: ByteArray): AudioPacket? {
            if (data.size < HEADER_SIZE) return null
            val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
            val streamGeneration = buffer.getLong()
            val sequenceNumber = buffer.getInt()
            val captureTimestampNanos = buffer.getLong()
            val sampleRate = buffer.getInt()
            val channelCount = buffer.getInt()
            val payloadSize = data.size - HEADER_SIZE
            val payload = ByteArray(payloadSize)
            buffer.get(payload)
            return AudioPacket(
                streamGeneration = streamGeneration,
                sequenceNumber = sequenceNumber,
                captureTimestampNanos = captureTimestampNanos,
                sampleRate = sampleRate,
                channelCount = channelCount,
                payload = payload,
            )
        }
    }

    /** Total wire size in bytes. */
    val wireSize: Int
        get() = HEADER_SIZE + payload.size
}