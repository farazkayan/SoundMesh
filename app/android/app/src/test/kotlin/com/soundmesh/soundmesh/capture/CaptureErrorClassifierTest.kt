package com.soundmesh.soundmesh.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Phase 5 — error classification: each audio-api.md §14 error code must be
 * distinctly reachable, never collapsed into one generic error.
 */
class CaptureErrorClassifierTest {

    @Test
    fun `SecurityException maps to PERMISSION_DENIED`() {
        val error = CaptureErrorClassifier.classify(SecurityException("not authorized"))
        assertEquals(CaptureErrorClassifier.PERMISSION_DENIED, error.code)
        assertTrue(error.message.contains("SecurityException"))
        assertTrue(error.message.contains("not authorized"))
    }

    @Test
    fun `UnsupportedOperationException maps to CAPTURE_UNSUPPORTED`() {
        val error = CaptureErrorClassifier.classify(
            UnsupportedOperationException("requires API 29"),
        )
        assertEquals(CaptureErrorClassifier.CAPTURE_UNSUPPORTED, error.code)
        assertTrue(error.message.contains("API 29"))
    }

    @Test
    fun `IllegalArgumentException maps to CAPTURE_START_FAILED`() {
        val error = CaptureErrorClassifier.classify(IllegalArgumentException("bad buffer"))
        assertEquals(CaptureErrorClassifier.CAPTURE_START_FAILED, error.code)
        assertTrue(error.message.contains("bad buffer"))
    }

    @Test
    fun `generic exceptions map to CAPTURE_START_FAILED with underlying detail`() {
        val error = CaptureErrorClassifier.classify(RuntimeException("audio record init failed"))
        assertEquals(CaptureErrorClassifier.CAPTURE_START_FAILED, error.code)
        // The contract requires the underlying exception message, not a bare code.
        assertTrue(error.message.contains("RuntimeException"))
        assertTrue(error.message.contains("audio record init failed"))
    }

    @Test
    fun `read errors map to CAPTURE_INTERRUPTED`() {
        val error = CaptureErrorClassifier.classifyReadError(android.media.AudioRecord.ERROR_DEAD_OBJECT)
        assertEquals(CaptureErrorClassifier.CAPTURE_INTERRUPTED, error.code)
        assertTrue(error.message.contains("ERROR_DEAD_OBJECT"))
    }

    @Test
    fun `projection revocation maps to CAPTURE_INTERRUPTED with specific message`() {
        val error = CaptureErrorClassifier.projectionRevoked()
        assertEquals(CaptureErrorClassifier.CAPTURE_INTERRUPTED, error.code)
        assertTrue(error.message.contains("revoked"))
    }

    @Test
    fun `all five error codes are distinct`() {
        val codes = listOf(
            CaptureErrorClassifier.PERMISSION_DENIED,
            CaptureErrorClassifier.CAPTURE_UNSUPPORTED,
            CaptureErrorClassifier.SOURCE_APP_BLOCKED,
            CaptureErrorClassifier.CAPTURE_START_FAILED,
            CaptureErrorClassifier.CAPTURE_INTERRUPTED,
        )
        assertEquals(codes.size, codes.toSet().size)
    }
}
