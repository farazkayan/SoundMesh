package com.soundmesh.soundmesh

import java.nio.charset.StandardCharsets

internal class FrameDecoder(
    private val onFrameStarted: () -> Unit = {},
    private val onFrameCompleted: (Int) -> Unit = {},
    private val onInvalidLength: (Long) -> Unit = {},
) {
    private val headerBuffer = ByteArray(FRAME_LENGTH_BYTES)
    private var headerBytesRead = 0
    private var payloadBuffer: ByteArray? = null
    private var payloadBytesRead = 0
    private var skipBytesRemaining = 0L

    fun accept(
        data: ByteArray,
        offset: Int = 0,
        byteCount: Int = data.size - offset,
    ): List<String> {
        require(offset >= 0 && byteCount >= 0 && byteCount <= data.size - offset) {
            "Invalid range: offset=$offset, byteCount=$byteCount, size=${data.size}"
        }

        val messages = mutableListOf<String>()
        var index = offset
        val end = offset + byteCount
        while (index < end) {
            if (skipBytesRemaining > 0L) {
                // Discard the payload declared by an oversized frame header so
                // the byte stream stays in sync instead of its payload bytes
                // being misparsed as new frame headers.
                val toSkip = minOf(skipBytesRemaining, (end - index).toLong()).toInt()
                index += toSkip
                skipBytesRemaining -= toSkip
                continue
            }
            val payload = payloadBuffer
            if (payload == null) {
                if (headerBytesRead == 0) {
                    onFrameStarted()
                }
                headerBuffer[headerBytesRead++] = data[index++]
                if (headerBytesRead == FRAME_LENGTH_BYTES) {
                    val frameLength = readFrameLength()
                    if (frameLength == 0L) {
                        // An empty frame is fully consumed by its header; the
                        // next byte is a new frame header, so recovery is sound.
                        onInvalidLength(frameLength)
                        resetForNewFrame()
                        continue
                    }
                    if (frameLength > MAX_PAYLOAD_BYTES) {
                        onInvalidLength(frameLength)
                        skipBytesRemaining = frameLength
                        resetForNewFrame()
                        continue
                    }
                    payloadBuffer = ByteArray(frameLength.toInt())
                    payloadBytesRead = 0
                }
            } else {
                payload[payloadBytesRead++] = data[index++]
                if (payloadBytesRead == payload.size) {
                    messages += String(payload, StandardCharsets.UTF_8)
                    resetForNewFrame()
                    onFrameCompleted(payload.size)
                }
            }
        }
        return messages
    }

    fun reset() {
        resetForNewFrame()
        skipBytesRemaining = 0L
    }

    private fun readFrameLength(): Long {
        // Unsigned 32-bit big-endian length. A signed Int read turns a header
        // byte >= 0x80 into a negative length, hiding oversized (or hostile)
        // length headers and desyncing the stream.
        return ((headerBuffer[0].toLong() and 0xFF) shl 24) or
            ((headerBuffer[1].toLong() and 0xFF) shl 16) or
            ((headerBuffer[2].toLong() and 0xFF) shl 8) or
            (headerBuffer[3].toLong() and 0xFF)
    }

    private fun resetForNewFrame() {
        headerBytesRead = 0
        payloadBytesRead = 0
        payloadBuffer = null
    }

    companion object {
        private const val FRAME_LENGTH_BYTES = 4
        private const val MAX_PAYLOAD_BYTES = 65_536
    }
}
