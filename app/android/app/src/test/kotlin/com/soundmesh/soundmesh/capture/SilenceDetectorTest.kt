package com.soundmesh.soundmesh.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Phase 5 — silence heuristic backing SOURCE_APP_BLOCKED.
 *
 * Android does not throw when a source opts out: the capture session keeps
 * delivering all-zero PCM. The detector must fire exactly once per silence
 * episode and reset when real audio content returns.
 */
class SilenceDetectorTest {

    private val silentBytes = ByteArray(1024)
    private val loudBytes = ByteArray(1024) { (it * 7).toByte() }

    @Test
    fun `does not fire below threshold`() {
        val detector = SilenceDetector(threshold = 5)
        repeat(4) {
            assertFalse(detector.observe(silentBytes, silentBytes.size))
        }
        assertEquals(4, detector.consecutiveSilentReads())
    }

    @Test
    fun `fires exactly once when threshold crossed`() {
        val detector = SilenceDetector(threshold = 3)
        assertFalse(detector.observe(silentBytes, silentBytes.size))
        assertFalse(detector.observe(silentBytes, silentBytes.size))
        assertTrue(detector.observe(silentBytes, silentBytes.size))
        // Stays silent but must not fire again for the same episode.
        assertFalse(detector.observe(silentBytes, silentBytes.size))
        assertFalse(detector.observe(silentBytes, silentBytes.size))
    }

    @Test
    fun `real audio resets the episode`() {
        val detector = SilenceDetector(threshold = 3)
        detector.observe(silentBytes, silentBytes.size)
        detector.observe(silentBytes, silentBytes.size)
        // Real (non-zero) audio arrives.
        assertFalse(detector.observe(loudBytes, loudBytes.size))
        assertEquals(0, detector.consecutiveSilentReads())

        // A new silence episode requires a fresh full threshold crossing.
        assertFalse(detector.observe(silentBytes, silentBytes.size))
        assertFalse(detector.observe(silentBytes, silentBytes.size))
        assertTrue(detector.observe(silentBytes, silentBytes.size))
    }

    @Test
    fun `partial zero buffer is not silence`() {
        // Buffer with a single non-zero byte is real audio content.
        val mostlyZero = ByteArray(1024)
        mostlyZero[512] = 1
        val detector = SilenceDetector(threshold = 1)
        assertFalse(detector.observe(mostlyZero, mostlyZero.size))
        assertEquals(0, detector.consecutiveSilentReads())
    }

    @Test
    fun `reset clears episode state`() {
        val detector = SilenceDetector(threshold = 2)
        detector.observe(silentBytes, silentBytes.size)
        detector.reset()
        assertEquals(0, detector.consecutiveSilentReads())
        assertFalse(detector.observe(silentBytes, silentBytes.size))
    }
}
