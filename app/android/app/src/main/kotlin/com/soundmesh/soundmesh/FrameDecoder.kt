package com.soundmesh.soundmesh

import java.nio.charset.StandardCharsets

internal class FrameDecoder(
    private val onFrameStarted: () -> Unit = {},
    private val onFrameCompleted: (Int) -> Unit = {},
    private val onInvalidLength: (Int) -> Unit = {},
) {
    private val headerBuffer = ByteArray(FRAME_LENGTH_BYTES)
    private var headerBytesRead = 0
    private var payloadBuffer: ByteArray? = null
    private var payloadBytesRead = 0

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
            val payload = payloadBuffer
            if (payload == null) {
                if (headerBytesRead == 0) {
                    onFrameStarted()
                }
                headerBuffer[headerBytesRead++] = data[index++]
                if (headerBytesRead == FRAME_LENGTH_BYTES) {
                    val frameLength = readFrameLength()
                    if (frameLength <= 0 || frameLength > MAX_PAYLOAD_BYTES) {
                        onInvalidLength(frameLength)
                        resetForNewFrame()
                        continue
                    }
                    payloadBuffer = ByteArray(frameLength)
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
    }

    private fun readFrameLength(): Int {
        return ((headerBuffer[0].toInt() and 0xFF) shl 24) or
            ((headerBuffer[1].toInt() and 0xFF) shl 16) or
            ((headerBuffer[2].toInt() and 0xFF) shl 8) or
            (headerBuffer[3].toInt() and 0xFF)
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
