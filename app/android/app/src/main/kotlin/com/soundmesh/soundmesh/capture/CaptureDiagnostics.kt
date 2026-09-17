package com.soundmesh.soundmesh.capture

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

/**
 * Phase 5 feasibility spike — native diagnostic surface.
 *
 * The Phase 5 requirement is to observe that raw PCM frames are actually
 * arriving natively — without piping any raw audio across the Flutter/native
 * boundary (architecture.md Flutter/native separation, audio-api.md §24
 * restricts the Flutter-facing surface to state/metadata/error events).
 *
 * Therefore the diagnostic surface is structured Logcat output, emitted on a
 * fixed interval, observable via:
 *   adb logcat -s AudioCaptureEngine
 *
 * Phase 8's transport will replace this consumer; until then the stats below
 * are the evidence that capture is producing frames.
 */
class CaptureDiagnostics(private val scope: CoroutineScope) {
    private val framesReceived = AtomicLong(0)
    private val bytesReceived = AtomicLong(0)
    private val silentReads = AtomicLong(0)
    private var sampleRate = 0
    private var channelCount = 0
    private var encoding = "unknown"
    private var statsJob: Job? = null

    data class CaptureStats(
        val framesPerSecond: Double,
        val bytesPerSecond: Double,
        val sampleRate: Int,
        val channelCount: Int,
        val encoding: String,
        val totalFrames: Long,
        val totalBytes: Long,
        val silentReads: Long,
    )

    fun recordFrame(byteCount: Int, silent: Boolean) {
        framesReceived.incrementAndGet()
        bytesReceived.addAndGet(byteCount.toLong())
        if (silent) silentReads.incrementAndGet()
    }

    fun setFormat(sampleRate: Int, channelCount: Int, encoding: String) {
        this.sampleRate = sampleRate
        this.channelCount = channelCount
        this.encoding = encoding
    }

    fun start(intervalMs: Long = DEFAULT_INTERVAL_MS) {
        stop()
        statsJob = scope.launch(Dispatchers.IO) {
            var lastFrames = 0L
            var lastBytes = 0L
            var lastTime = System.currentTimeMillis()
            while (true) {
                delay(intervalMs)
                val now = System.currentTimeMillis()
                val elapsedSec = (now - lastTime) / 1000.0
                if (elapsedSec <= 0.0) continue

                val totalFrames = framesReceived.get()
                val totalBytes = bytesReceived.get()
                val stats = CaptureStats(
                    framesPerSecond = (totalFrames - lastFrames) / elapsedSec,
                    bytesPerSecond = (totalBytes - lastBytes) / elapsedSec,
                    sampleRate = sampleRate,
                    channelCount = channelCount,
                    encoding = encoding,
                    totalFrames = totalFrames,
                    totalBytes = totalBytes,
                    silentReads = silentReads.get(),
                )
                log(stats)
                lastFrames = totalFrames
                lastBytes = totalBytes
                lastTime = now
            }
        }
    }

    fun stop() {
        statsJob?.cancel()
        statsJob = null
    }

    fun reset() {
        framesReceived.set(0)
        bytesReceived.set(0)
        silentReads.set(0)
    }

    private fun log(stats: CaptureStats) {
        Log.d(
            TAG,
            "[CaptureStats] frames=${"%.1f".format(stats.framesPerSecond)}/s " +
                "bytes=${"%.0f".format(stats.bytesPerSecond)}/s " +
                "format=${stats.sampleRate}Hz/${stats.channelCount}ch/${stats.encoding} " +
                "totalFrames=${stats.totalFrames} totalBytes=${stats.totalBytes} " +
                "silentReads=${stats.silentReads}",
        )
    }

    companion object {
        private const val TAG = "AudioCaptureEngine"
        private const val DEFAULT_INTERVAL_MS = 500L
    }
}
