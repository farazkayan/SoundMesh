package com.soundmesh.soundmesh

import org.junit.Assert.assertEquals
import org.junit.Test

class FrameDecoderTest {
    @Test
    fun decodesShortPayload() {
        val decoder = FrameDecoder()

        val messages = decoder.accept(frame("PING"))

        assertEquals(listOf("PING"), messages)
    }

    @Test
    fun decodesLongerPayload() {
        val decoder = FrameDecoder()

        val messages = decoder.accept(frame("HELLO"))

        assertEquals(listOf("HELLO"), messages)
    }

    @Test
    fun decodesWhenHeaderAndPayloadAreSplitAcrossReads() {
        val decoder = FrameDecoder()
        val frame = frame("PING")
        val messages = mutableListOf<String>()

        messages += decoder.accept(frame.copyOfRange(0, 2))
        messages += decoder.accept(frame.copyOfRange(2, 6))
        messages += decoder.accept(frame.copyOfRange(6, 8))

        assertEquals(listOf("PING"), messages)
    }

    @Test
    fun decodesLongerPayloadWhenReadCrossesHeaderBoundary() {
        val decoder = FrameDecoder()
        val frame = frame("HELLO")
        val messages = mutableListOf<String>()

        messages += decoder.accept(frame.copyOfRange(0, 1))
        messages += decoder.accept(frame.copyOfRange(1, 6))
        messages += decoder.accept(frame.copyOfRange(6, 9))

        assertEquals(listOf("HELLO"), messages)
    }

    @Test
    fun resetsStateBetweenConsecutiveFrames() {
        val decoder = FrameDecoder()
        val frames = frame("PING") + frame("HELLO")

        val messages = decoder.accept(frames)

        assertEquals(listOf("PING", "HELLO"), messages)
    }

    @Test
    fun resetsAfterInvalidLengthAndReadsNextFrame() {
        val decoder = FrameDecoder()
        val invalidHeader = byteArrayOf(0, 0, 0, 0)
        val validFrame = frame("PING")

        val messages = decoder.accept(invalidHeader + validFrame)

        assertEquals(listOf("PING"), messages)
    }

    @Test
    fun skipsOversizedPayloadAndReadsNextFrame() {
        val decoder = FrameDecoder()
        // 0x00010001 = 65537 > MAX_PAYLOAD_BYTES (65536)
        val oversizedHeader = byteArrayOf(0, 1, 0, 1)
        val validFrame = frame("PING")

        val messages = decoder.accept(oversizedHeader + ByteArray(65537) + validFrame)

        assertEquals(listOf("PING"), messages)
    }

    @Test
    fun skipsOversizedPayloadAcrossSeparateReads() {
        val decoder = FrameDecoder()
        val oversizedHeader = byteArrayOf(0, 1, 0, 1)
        val oversizedPayload = ByteArray(65537)
        val validFrame = frame("PING")

        val messages = mutableListOf<String>()
        messages += decoder.accept(oversizedHeader)
        messages += decoder.accept(oversizedPayload.copyOfRange(0, 4096))
        messages += decoder.accept(oversizedPayload.copyOfRange(4096, oversizedPayload.size))
        messages += decoder.accept(validFrame)

        assertEquals(listOf("PING"), messages)
    }

    private fun frame(payload: String): ByteArray {
        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        return ByteArray(FRAME_LENGTH_BYTES + payloadBytes.size).apply {
            this[0] = (payloadBytes.size shr 24).toByte()
            this[1] = (payloadBytes.size shr 16).toByte()
            this[2] = (payloadBytes.size shr 8).toByte()
            this[3] = payloadBytes.size.toByte()
            payloadBytes.copyInto(this, FRAME_LENGTH_BYTES)
        }
    }

    private companion object {
        private const val FRAME_LENGTH_BYTES = 4
    }
}
