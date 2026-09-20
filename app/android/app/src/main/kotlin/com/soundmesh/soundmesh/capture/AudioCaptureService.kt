package com.soundmesh.soundmesh.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.CompletableDeferred

/**
 * Phase 5 feasibility spike — foreground service required while capturing.
 *
 * Android requires a mediaProjection-type foreground service with a persistent
 * notification for the lifetime of the capture session (audio-api.md §22).
 * This is a platform requirement, not a design choice.
 *
 * The notification UX is deliberately minimal per Phase 5 scope (owner:
 * Faraz's directive — "minimal notification"); the final UX is UNDECIDED and
 * may need Mahin's input later (audio-api.md §22, open question §40.5).
 */
class AudioCaptureService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        // Register this service instance for notification updates
        AudioCaptureService.setServiceInstance(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_CAPTURE -> {
                Log.i(TAG, "Stop action received from notification")
                stopListener?.invoke()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        Log.d(TAG, "Foreground service started (mediaProjection type)")

        // Signal the engine that startForeground() has completed — required
        // before getMediaProjection() on Android 14+.
        foregroundReadySignal?.complete(Unit)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        AudioCaptureService.setServiceInstance(null)
        Log.d(TAG, "Foreground service stopped")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SoundMesh Audio Capture",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Active audio capture session for SoundMesh synchronization"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(isReceivingAudio: Boolean = false, isSilent: Boolean = false): Notification {
        val stopIntent = Intent(this, AudioCaptureService::class.java).apply {
            action = ACTION_STOP_CAPTURE
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val text = if (isReceivingAudio) {
            if (isSilent) {
                "Capturing audio: Silent (no audio detected)"
            } else {
                "Capturing audio: Receiving audio"
            }
        } else {
            "Capturing audio: No frames arriving"
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("SoundMesh")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(
                android.R.drawable.ic_media_pause,
                "Stop",
                stopPendingIntent,
            )
            .build()
    }

    /**
     * Update the foreground notification content text with live capture status.
     * Called from the capture engine on each frame-stats interval (~500ms).
     */
    fun updateNotificationContent(isReceivingAudio: Boolean, isSilent: Boolean) {
        val notification = buildNotification(isReceivingAudio, isSilent)
        // Update the existing foreground notification in-place (no flicker)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        private const val TAG = "AudioCaptureService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "soundmesh_capture_channel"
        const val ACTION_STOP_CAPTURE = "com.soundmesh.soundmesh.capture.STOP_CAPTURE"

        /**
         * Completes when the service has actually called startForeground().
         * The engine awaits this before calling getMediaProjection() because
         * Android 14 throws if the mediaProjection FGS is not yet foreground.
         */
        @Volatile private var foregroundReadySignal: CompletableDeferred<Unit>? = null

        /** Listener invoked when the user taps "Stop" on the notification. */
        @Volatile private var stopListener: (() -> Unit)? = null

        /**
         * Start the foreground service and suspend until startForeground()
         * has run. Times out (returns false) so a wedged service can never
         * hang startCapture() forever.
         */
        suspend fun startAwaitingForeground(context: Context, timeoutMs: Long = 5_000): Boolean {
            val ready = CompletableDeferred<Unit>()
            foregroundReadySignal = ready
            val intent = Intent(context, AudioCaptureService::class.java)
            context.startForegroundService(intent)
            val result = kotlinx.coroutines.withTimeoutOrNull(timeoutMs) { ready.await() }
            foregroundReadySignal = null
            if (result == null) {
                Log.w(TAG, "Foreground service did not reach foreground state within ${timeoutMs}ms")
                return false
            }
            return true
        }

        fun setStopListener(listener: (() -> Unit)?) {
            stopListener = listener
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AudioCaptureService::class.java))
        }

        /**
         * Update the notification content from anywhere (e.g. capture engine).
         * Safe to call when service is not running — no-op.
         */
        @Volatile private var serviceInstance: AudioCaptureService? = null

        internal fun setServiceInstance(instance: AudioCaptureService?) {
            serviceInstance = instance
        }

        fun updateNotification(isReceivingAudio: Boolean, isSilent: Boolean) {
            serviceInstance?.updateNotificationContent(isReceivingAudio, isSilent)
        }
    }
}
