package com.soundmesh.soundmesh.capture

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Phase 5 feasibility spike — MediaProjection consent flow.
 *
 * Owns the user-facing permission sequence required before AudioPlaybackCapture:
 *
 *   1. RECORD_AUDIO runtime permission (required to build a capture AudioRecord)
 *   2. MediaProjection consent dialog (system activity result)
 *
 * The consent grant is one-shot: startCapture() consumes it exactly once,
 * matching Android 14+ (API 34) behavior where a consent token cannot be
 * reused for a second getMediaProjection() call.
 */
class MediaProjectionHelper(private val activity: Activity) {
    private val TAG = "MediaProjectionHelper"
    private val mediaProjectionManager: MediaProjectionManager =
        activity.getSystemService(MediaProjectionManager::class.java)

    /** The single-use consent grant produced by a successful permission request. */
    data class Grant(val resultCode: Int, val data: Intent)

    private var runtimePermissionResult: CompletableDeferred<Boolean>? = null
    private var projectionResult: CompletableDeferred<Pair<Int, Intent?>>? = null

    @Volatile private var pendingGrant: Grant? = null

    /**
     * Runs the full permission sequence. Returns the Grant on success, or
     * null if the user (or platform) denied any step. Callers map the null
     * to PERMISSION_DENIED. Throws on plumbing failures, which callers map
     * via CaptureErrorClassifier.
     *
     * Must be called with an active Activity (audio-api.md §9) — the system
     * consent dialog requires a foreground Activity context.
     */
    suspend fun requestPermission(): Grant? {
        // Step 1: RECORD_AUDIO runtime permission.
        if (!hasRecordAudio()) {
            val granted = CompletableDeferred<Boolean>()
            runtimePermissionResult = granted
            try {
                withContext(Dispatchers.Main) {
                    activity.requestPermissions(
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        REQUEST_RECORD_AUDIO,
                    )
                }
            } catch (e: Exception) {
                runtimePermissionResult = null
                throw e
            }
            if (!granted.await()) {
                Log.w(TAG, "RECORD_AUDIO runtime permission denied by user")
                return null
            }
        }

        // Step 2: MediaProjection consent dialog.
        val result = CompletableDeferred<Pair<Int, Intent?>>()
        projectionResult = result
        try {
            withContext(Dispatchers.Main) {
                activity.startActivityForResult(
                    mediaProjectionManager.createScreenCaptureIntent(),
                    REQUEST_MEDIA_PROJECTION,
                )
            }
        } catch (e: Exception) {
            projectionResult = null
            throw e
        }

        val (resultCode, data) = result.await()
        return if (resultCode == Activity.RESULT_OK && data != null) {
            val grant = Grant(resultCode, data)
            pendingGrant = grant
            Log.i(TAG, "MediaProjection consent granted")
            grant
        } else {
            Log.w(TAG, "MediaProjection consent denied by user (resultCode=$resultCode)")
            null
        }
    }

    /**
     * Activity-result hook — must be called from the Activity's
     * onActivityResult for this request code.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_MEDIA_PROJECTION) return false
        projectionResult?.complete(resultCode to data)
        projectionResult = null
        return true
    }

    /**
     * Runtime-permission hook — must be called from the Activity's
     * onRequestPermissionsResult.
     */
    fun onRuntimePermissionResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_RECORD_AUDIO) return false
        val granted = permissions.indexOf(Manifest.permission.RECORD_AUDIO).let { index ->
            index >= 0 && grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        }
        runtimePermissionResult?.complete(granted)
        runtimePermissionResult = null
        return true
    }

    /**
     * Take (and clear) the pending consent grant. One-shot: Android 14
     * forbids reusing a consent token, so the grant is consumed exactly once.
     */
    fun consumeGrant(): Grant? {
        val grant = pendingGrant
        pendingGrant = null
        return grant
    }

    /** Discard any pending grant without using it. */
    fun discardGrant() {
        pendingGrant = null
    }

    /**
     * Create the MediaProjection. On Android 14+ this MUST be called only
     * after the mediaProjection-type foreground service is in the started
     * foreground state (AudioCaptureService.startAwaitingForeground),
     * otherwise the system throws. See engine start order.
     */
    fun createProjection(grant: Grant): MediaProjection {
        return mediaProjectionManager.getMediaProjection(grant.resultCode, grant.data)
            ?: throw IllegalStateException(
                "getMediaProjection returned null for resultCode=${grant.resultCode} " +
                    "(grant may have been consumed already — Android 14 consent tokens are single-use)",
            )
    }

    private fun hasRecordAudio(): Boolean =
        activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    companion object {
        const val REQUEST_MEDIA_PROJECTION = 0xCA77
        const val REQUEST_RECORD_AUDIO = 0xA0D10
    }
}
