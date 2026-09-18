package com.soundmesh.soundmesh.capture

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Phase 5 — state machine transitions required by audio-api.md §15:
 *
 *   IDLE → REQUESTING_PERMISSION → PERMISSION_GRANTED → CAPTURING → STOPPED
 *                                 ↘ PERMISSION_DENIED
 *   CAPTURING → FAILED
 */
class CaptureStateMachineTest {

    @Test
    fun `initial state is IDLE`() {
        val machine = CaptureStateMachine()
        assertEquals(CaptureSessionState.IDLE, machine.state())
    }

    @Test
    fun `happy path - grant then capture then stop`() {
        val machine = CaptureStateMachine()
        assertTrue(machine.beginPermissionRequest())
        assertEquals(CaptureSessionState.REQUESTING_PERMISSION, machine.state())

        assertEquals(
            CaptureSessionState.PERMISSION_GRANTED,
            machine.onPermissionResult(granted = true),
        )
        assertTrue(machine.startCapture())
        assertEquals(CaptureSessionState.CAPTURING, machine.state())

        assertEquals(CaptureSessionState.STOPPED, machine.stopCapture())
    }

    @Test
    fun `permission denied branch`() {
        val machine = CaptureStateMachine()
        assertTrue(machine.beginPermissionRequest())
        assertEquals(
            CaptureSessionState.PERMISSION_DENIED,
            machine.onPermissionResult(granted = false),
        )
        // Denial is terminal for this session but retrying is allowed.
        assertTrue(machine.beginPermissionRequest())
    }

    @Test
    fun `start capture without permission is rejected`() {
        val machine = CaptureStateMachine()
        assertFalse(machine.startCapture())
        assertEquals(CaptureSessionState.IDLE, machine.state())
    }

    @Test
    fun `capturing to FAILED on interruption`() {
        val machine = CaptureStateMachine()
        machine.beginPermissionRequest()
        machine.onPermissionResult(granted = true)
        machine.startCapture()

        assertEquals(
            CaptureSessionState.FAILED,
            machine.fail(CaptureErrorClassifier.CAPTURE_INTERRUPTED, "source stopped"),
        )
        assertEquals(
            CaptureErrorClassifier.CAPTURE_INTERRUPTED to "source stopped",
            machine.error(),
        )
    }

    @Test
    fun `stop then request again for next session`() {
        val machine = CaptureStateMachine()
        machine.beginPermissionRequest()
        machine.onPermissionResult(granted = true)
        machine.startCapture()
        machine.stopCapture()

        // Consent is per-session: a new session requires a new permission grant.
        assertTrue(machine.beginPermissionRequest())
        assertEquals(CaptureSessionState.REQUESTING_PERMISSION, machine.state())
    }

    @Test
    fun `stop is a no-op from IDLE`() {
        val machine = CaptureStateMachine()
        assertEquals(CaptureSessionState.IDLE, machine.stopCapture())
    }

    @Test
    fun `double start is rejected`() {
        val machine = CaptureStateMachine()
        machine.beginPermissionRequest()
        machine.onPermissionResult(granted = true)
        assertTrue(machine.startCapture())
        assertFalse(machine.startCapture())
        assertEquals(CaptureSessionState.CAPTURING, machine.state())
    }

    @Test
    fun `duplicate permission request while requesting is rejected`() {
        val machine = CaptureStateMachine()
        assertTrue(machine.beginPermissionRequest())
        assertFalse(machine.beginPermissionRequest())
        assertEquals(CaptureSessionState.REQUESTING_PERMISSION, machine.state())
    }

    @Test
    fun `stale permission result after failure is ignored`() {
        val machine = CaptureStateMachine()
        machine.beginPermissionRequest()
        machine.onPermissionFailed(CaptureErrorClassifier.CAPTURE_START_FAILED, "boom")
        assertEquals(CaptureSessionState.FAILED, machine.state())

        // A late dialog result must not resurrect a failed session.
        assertEquals(
            CaptureSessionState.FAILED,
            machine.onPermissionResult(granted = true),
        )
        assertFalse(machine.canStartCapture())
    }

    @Test
    fun `fail only transitions from CAPTURING`() {
        val machine = CaptureStateMachine()
        machine.beginPermissionRequest()
        // Failing while still REQUESTING_PERMISSION is a no-op here; the
        // caller uses onPermissionFailed for that transition.
        assertEquals(
            CaptureSessionState.REQUESTING_PERMISSION,
            machine.fail(CaptureErrorClassifier.CAPTURE_INTERRUPTED, "x"),
        )
        assertNull(machine.error())
    }

    @Test
    fun `canStartCapture only true in PERMISSION_GRANTED`() {
        val machine = CaptureStateMachine()
        assertFalse(machine.canStartCapture())
        machine.beginPermissionRequest()
        assertFalse(machine.canStartCapture())
        machine.onPermissionResult(granted = true)
        assertTrue(machine.canStartCapture())
        machine.startCapture()
        assertFalse(machine.canStartCapture())
    }

    @Test
    fun `reset returns to IDLE and clears error`() {
        val machine = CaptureStateMachine()
        machine.beginPermissionRequest()
        machine.onPermissionResult(granted = true)
        machine.startCapture()
        machine.fail(CaptureErrorClassifier.CAPTURE_INTERRUPTED, "revoked")

        machine.reset()
        assertEquals(CaptureSessionState.IDLE, machine.state())
        assertNull(machine.error())
    }
}
