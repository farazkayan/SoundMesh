package com.soundmesh.soundmesh.capture

/**
 * Phase 5 feasibility spike — silence heuristic for SOURCE_APP_BLOCKED.
 *
 * Android does NOT throw when a source app opts out of AudioPlaybackCapture
 * (ALLOW_CAPTURE_BY_* policy): the capture session keeps running but delivers
 * all-zero PCM instead of real audio. The only native-visible signature of
 * a blocked source is therefore sustained digital silence while frames keep
 * arriving.
 *
 * This detector fires once per silence episode after [threshold] consecutive
 * silent reads. CAUTION (audio-api.md §14 NO_AUDIO_PLAYING, open question
 * §40.2): sustained silence is ambiguous — it may mean the source app is
 * paused/muted rather than blocked. The error is surfaced distinctly but the
 * capture loop is NOT torn down, so a paused-then-resumed source recovers
 * naturally. This ambiguity is exactly what the real-device experiment must
 * characterize.
 */
class SilenceDetector(private val threshold: Int = DEFAULT_THRESHOLD) {
    private var consecutiveSilentReads = 0
    private var firedForCurrentEpisode = false

    /**
     * Observe one read of [length] bytes from [buffer].
     * Returns true exactly once per silence episode when the threshold is
     * crossed.
     */
    fun observe(buffer: ByteArray, length: Int): Boolean {
        if (isAllZero(buffer, length)) {
            consecutiveSilentReads++
            if (consecutiveSilentReads >= threshold && !firedForCurrentEpisode) {
                firedForCurrentEpisode = true
                return true
            }
        } else {
            // Real audio content resets the silence episode.
            consecutiveSilentReads = 0
            firedForCurrentEpisode = false
        }
        return false
    }

    fun reset() {
        consecutiveSilentReads = 0
        firedForCurrentEpisode = false
    }

    fun consecutiveSilentReads(): Int = consecutiveSilentReads

    private fun isAllZero(buffer: ByteArray, length: Int): Boolean {
        // 16-bit PCM digital silence is all zero bytes.
        for (i in 0 until length) {
            if (buffer[i].toInt() != 0) return false
        }
        return true
    }

    companion object {
        /**
         * Default: 25 consecutive silent reads. Each blocking read at
         * 44.1 kHz stereo 16-bit is ~ 40 ms of audio, so 25 reads ≈ 1 s of
         * continuous digital silence.
         */
        const val DEFAULT_THRESHOLD = 25
    }
}
