package com.soundmesh.soundmesh.capture

/**
 * Maps native capture exceptions to the distinct error codes required by
 * DOCS/interfaces/audio-api.md §14:
 *
 * - PERMISSION_DENIED      — user declined MediaProjection (or RECORD_AUDIO was denied)
 * - CAPTURE_UNSUPPORTED    — device/Android version cannot support AudioPlaybackCapture
 * - SOURCE_APP_BLOCKED     — target app opted out of capture (sustained silence heuristic)
 * - CAPTURE_START_FAILED   — generic native failure, must carry the underlying cause
 * - CAPTURE_INTERRUPTED    — active capture ended unexpectedly (revocation, read failure)
 *
 * These MUST NOT be collapsed into a single generic error (Phase 5 task
 * error-handling requirement). Every classified error includes the underlying
 * native detail, per audio-api.md §26.
 */
object CaptureErrorClassifier {
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val CAPTURE_UNSUPPORTED = "CAPTURE_UNSUPPORTED"
    const val SOURCE_APP_BLOCKED = "SOURCE_APP_BLOCKED"
    const val CAPTURE_START_FAILED = "CAPTURE_START_FAILED"
    const val CAPTURE_INTERRUPTED = "CAPTURE_INTERRUPTED"

    data class ClassifiedError(
        val code: String,
        val message: String,
    )

    /** Classify a failure that occurred while starting capture. */
    fun classify(exception: Throwable): ClassifiedError {
        val detail = "${exception.javaClass.simpleName}: ${exception.message}"
        return when (exception) {
            is SecurityException -> ClassifiedError(
                PERMISSION_DENIED,
                "MediaProjection/RECORD_AUDIO permission denied: $detail",
            )
            is UnsupportedOperationException -> ClassifiedError(
                CAPTURE_UNSUPPORTED,
                "AudioPlaybackCapture not supported on this device/Android version: $detail",
            )
            is IllegalArgumentException -> ClassifiedError(
                CAPTURE_START_FAILED,
                "Invalid capture configuration: $detail",
            )
            else -> ClassifiedError(
                CAPTURE_START_FAILED,
                "Capture start failed: $detail",
            )
        }
    }

    /** Map an AudioRecord.read error code to a distinct interruption error. */
    fun classifyReadError(readResult: Int): ClassifiedError {
        val detail = when (readResult) {
            android.media.AudioRecord.ERROR_INVALID_OPERATION -> "ERROR_INVALID_OPERATION"
            android.media.AudioRecord.ERROR_BAD_VALUE -> "ERROR_BAD_VALUE"
            android.media.AudioRecord.ERROR_DEAD_OBJECT -> "ERROR_DEAD_OBJECT (MediaProjection or audio pipeline died)"
            else -> "read returned $readResult"
        }
        return ClassifiedError(
            CAPTURE_INTERRUPTED,
            "Capture interrupted while reading audio: $detail",
        )
    }

    /** Error used when MediaProjection is revoked mid-capture. */
    fun projectionRevoked(): ClassifiedError = ClassifiedError(
        CAPTURE_INTERRUPTED,
        "Capture interrupted: MediaProjection grant was revoked by the system or user",
    )
}
