package com.soundmesh.soundmesh.capture

/**
 * Phase 5 feasibility spike — capture session state machine.
 *
 * Implements the state machine required by DOCS/interfaces/audio-api.md §15:
 *
 *   IDLE → REQUESTING_PERMISSION → PERMISSION_GRANTED → CAPTURING → STOPPED
 *                                 ↘ PERMISSION_DENIED
 *   CAPTURING → FAILED (on interruption/unrecoverable error)
 *
 * The enum is named CaptureSessionState to avoid clashing with the
 * Pigeon-generated wire type `com.soundmesh.soundmesh.CaptureState`,
 * which carries the state as a string across the platform boundary.
 */
enum class CaptureSessionState {
    IDLE,
    REQUESTING_PERMISSION,
    PERMISSION_GRANTED,
    PERMISSION_DENIED,
    CAPTURING,
    STOPPED,
    FAILED,
}

/**
 * Explicit, validated transition table. Invalid transitions are rejected
 * rather than silently coerced (DOCS/AI/rules.md §27).
 */
class CaptureStateMachine {
    private val lock = Any()
    private var currentState = CaptureSessionState.IDLE
    private var currentError: Pair<String, String>? = null

    fun state(): CaptureSessionState = synchronized(lock) { currentState }

    fun error(): Pair<String, String>? = synchronized(lock) { currentError }

    /**
     * Begin a permission request. Allowed from the "cold" states so the user
     * can retry after a denial or restart after a failure/stop.
     */
    fun beginPermissionRequest(): Boolean = synchronized(lock) {
        when (currentState) {
            CaptureSessionState.IDLE,
            CaptureSessionState.PERMISSION_DENIED,
            CaptureSessionState.STOPPED,
            CaptureSessionState.FAILED -> {
                currentState = CaptureSessionState.REQUESTING_PERMISSION
                currentError = null
                true
            }
            else -> false
        }
    }

    /**
     * Record the user's answer to the MediaProjection consent dialog.
     * Only valid while REQUESTING_PERMISSION; otherwise the transition is
     * ignored (stale result).
     */
    fun onPermissionResult(granted: Boolean): CaptureSessionState = synchronized(lock) {
        if (currentState == CaptureSessionState.REQUESTING_PERMISSION) {
            currentState = if (granted) {
                CaptureSessionState.PERMISSION_GRANTED
            } else {
                CaptureSessionState.PERMISSION_DENIED
            }
        }
        currentState
    }

    /**
     * Permission flow failed (e.g. dialog plumbing error). Only valid while
     * REQUESTING_PERMISSION.
     */
    fun onPermissionFailed(code: String, message: String): CaptureSessionState = synchronized(lock) {
        if (currentState == CaptureSessionState.REQUESTING_PERMISSION) {
            currentError = code to message
            currentState = CaptureSessionState.FAILED
        }
        currentState
    }

    /** Permission granted → capturing. */
    fun startCapture(): Boolean = synchronized(lock) {
        if (currentState == CaptureSessionState.PERMISSION_GRANTED) {
            currentState = CaptureSessionState.CAPTURING
            true
        } else {
            false
        }
    }

    /**
     * Stop capture. Per audio-api.md §11 stopCapture must be a safe
     * request; this machine records the STOPPED state when there was
     * something to stop (capturing or a granted-but-unused permission).
     */
    fun stopCapture(): CaptureSessionState = synchronized(lock) {
        when (currentState) {
            CaptureSessionState.CAPTURING, CaptureSessionState.PERMISSION_GRANTED -> {
                currentState = CaptureSessionState.STOPPED
            }
            else -> Unit
        }
        currentState
    }

    /**
     * Active capture failed or was interrupted (audio-api.md §14 error
     * surface). Only transitions CAPTURING → FAILED.
     */
    fun fail(code: String, message: String): CaptureSessionState = synchronized(lock) {
        if (currentState == CaptureSessionState.CAPTURING) {
            currentError = code to message
            currentState = CaptureSessionState.FAILED
        }
        currentState
    }

    fun isCapturing(): Boolean = synchronized(lock) { currentState == CaptureSessionState.CAPTURING }

    fun canStartCapture(): Boolean =
        synchronized(lock) { currentState == CaptureSessionState.PERMISSION_GRANTED }

    /** Test/lifecycle reset back to cold IDLE. */
    fun reset() = synchronized(lock) {
        currentState = CaptureSessionState.IDLE
        currentError = null
        Unit
    }
}
