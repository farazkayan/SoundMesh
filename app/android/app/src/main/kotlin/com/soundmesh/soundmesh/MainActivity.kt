package com.soundmesh.soundmesh

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Base64
import android.util.Log
import com.soundmesh.soundmesh.capture.AudioCaptureEngine
import com.soundmesh.soundmesh.capture.AudioCaptureService
import com.soundmesh.soundmesh.capture.CaptureErrorClassifier
import com.soundmesh.soundmesh.capture.CaptureSessionState
import com.soundmesh.soundmesh.capture.CaptureStateMachine
import com.soundmesh.soundmesh.capture.MediaProjectionHelper
import com.soundmesh.soundmesh.capture.CaptureDiagnostics
import com.soundmesh.soundmesh.FrameArrivalStats
import com.soundmesh.soundmesh.discovery.DiscoveryService
import com.soundmesh.soundmesh.output.AudioOutputEngine
import com.soundmesh.soundmesh.transport.AudioPacket
import com.soundmesh.soundmesh.transport.AudioReceiveEngine
import com.soundmesh.soundmesh.transport.AudioTransportEngine
import com.soundmesh.soundmesh.ReceiveState
import com.soundmesh.soundmesh.ReceiveStats
import com.soundmesh.soundmesh.OutputState
import com.soundmesh.soundmesh.StreamingMetadata
import com.soundmesh.soundmesh.StreamingState
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.InputStream
import java.io.OutputStream
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.NetworkInterface
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity(), DevicePlatform, TimingPlatform, NetworkHostPlatform,
    AudioCapturePlatform, AudioReceivePlatform, AudioOutputPlatform {
    private val TAG = "NetworkHandler"
    private val DEFAULT_PORT = 8765

    private val hostingLock = Any()
    @Volatile private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var connectionSocket: Socket? = null
    private var readerJob: Job? = null
    private var hostingJob: Job? = null
    private var hostingGeneration = 0L
    // Bumped by stopAll() and startReading(); state notifications from
    // superseded readers/attempts are suppressed so a stale "disconnected"
    // cannot land after a new attempt's "connecting".
    private var connectionGeneration = 0L
    private var isHosting = false
    private val scope = CoroutineScope(Dispatchers.IO)

    // ---- Phase 6: Heartbeat and reconnection ----
    private var heartbeatIntervalMs = 5000L
    private var heartbeatTimeoutMs = 15000L
    private var heartbeatJob: Job? = null
    private var lastHeartbeatReceivedMs = 0L
    @Volatile private var isReconnecting = false
    private var reconnectAttempts = 0
    private val maxReconnectAttempts = 5
    private var lastKnownHostIp: String? = null
    private var lastKnownHostPort = 8765
    private var currentParticipantId: String? = null

    // --- Diagnostic counters for BUG #3 pipeline tracing ---
    private val socketWritesAttempted = AtomicLong(0)
    private val socketWritesSucceeded = AtomicLong(0)
    private val socketWritesFailed = AtomicLong(0)
    private val socketBytesWritten = AtomicLong(0)
    private val lastSocketWriteTimestampNanos = AtomicLong(0)

    private val networkBytesReceived = AtomicLong(0)
    private val networkFramesDecoded = AtomicLong(0)
    private val lastNetworkReceiveTimestampNanos = AtomicLong(0)

    private val packetsParsed = AtomicLong(0)
    private val packetsParseFailed = AtomicLong(0)
    private val audioPacketsDispatched = AtomicLong(0)
    private val lastPacketParsedTimestampNanos = AtomicLong(0)

    private var networkDiagJob: Job? = null

    // --- Single-writer serialization for TCP frames (BUG #3 fix) ---
    @Volatile private var writerChannel = kotlinx.coroutines.channels.Channel<ByteArray>(capacity = 100)
    private var writerJob: Job? = null

    private var flutterApi: NetworkFlutterApi? = null

    // ---- Phase 5: external audio capture (feasibility spike) ----

    private val captureStateMachine = CaptureStateMachine()
    private var mediaProjectionHelper: MediaProjectionHelper? = null
    private var captureEngine: AudioCaptureEngine? = null
    private var captureFlutterApi: AudioCaptureFlutterApi? = null

    // Latest frame stats for notification updates when streaming state changes
    @Volatile private var lastFrameReceivingAudio = false
    @Volatile private var lastFrameIsSilent = false

    // ---- Phase 8: audio transport ----
    private var transportEngine: AudioTransportEngine? = null
    private var receiveEngine: AudioReceiveEngine? = null
    private var receiveFlutterApi: AudioReceiveFlutterApi? = null
    private var outputFlutterApi: AudioOutputFlutterApi? = null

    // ---- Phase 9: audio output ----
    private var outputEngine: AudioOutputEngine? = null

    // ---- Discovery ----
    private lateinit var discoveryService: DiscoveryService
    private val discoveryChannelName = "soundmesh/discovery"
    private var discoveryScanCallback: ((DiscoveryService.RoomAnnouncement?) -> Unit)? = null

    companion object {
        private const val FRAME_LENGTH_BYTES = 4
        private const val CONNECT_TIMEOUT_MS = 10_000
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // If the app was swiped away from recents while capture was active,
        // the foreground service (AudioCaptureService) survives but the Activity
        // is recreated fresh. Clean up any orphaned capture service/engine so
        // the new session starts with a clean slate. Only do this on a true
        // fresh launch (not config change like rotation) and when there's no
        // saved instance state to restore.
        if (!isChangingConfigurations && savedInstanceState == null) {
            Log.i(TAG, "Fresh launch detected — stopping any orphaned AudioCaptureService")
            AudioCaptureService.stop(this)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DevicePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        TimingPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        NetworkHostPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        flutterApi = NetworkFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        AudioCapturePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        captureFlutterApi = AudioCaptureFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        AudioReceivePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        receiveFlutterApi = AudioReceiveFlutterApi(flutterEngine.dartExecutor.binaryMessenger)

        // ---- Phase 9: AudioOutputPlatform ----
        AudioOutputPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        outputFlutterApi = AudioOutputFlutterApi(flutterEngine.dartExecutor.binaryMessenger)

        // Create transport engines
        transportEngine = AudioTransportEngine(
            context = this,
            scope = scope,
            sendProtocolMessage = { json -> sendProtocolMessage(json) },
            notifyStreamState = { state, metadata -> notifyStreamState(state, metadata) },
            notifyStreamError = { code, message -> notifyStreamError(code, message) },
        )
        receiveEngine = AudioReceiveEngine(
            scope = scope,
            notifyStreamState = { state, stats -> notifyReceiveState(state, stats) },
            notifyAudioLevel = { peakAmplitude, isSilent -> notifyReceiveAudioLevel(peakAmplitude, isSilent) },
        )
        outputEngine = AudioOutputEngine(
            context = this,
            scope = scope,
            notifyOutputState = { state, errorCode, errorMessage -> notifyOutputState(state, errorCode, errorMessage) },
        )

        // Wire receive engine to output engine
        outputEngine!!.setReceiveEngine(receiveEngine!!)

        // ---- Discovery ----
        discoveryService = DiscoveryService(this)
        val discoveryChannel = io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "soundmesh/discovery")
        discoveryChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startBroadcast" -> {
                    val code = call.argument<String>("code") ?: ""
                    val hostIp = call.argument<String>("hostIp") ?: ""
                    val hostPort = call.argument<Int>("hostPort") ?: 0
                    val roomId = call.argument<String>("roomId") ?: ""
                    val hostName = call.argument<String>("hostName")
                    val expiresAt = (call.argument<Number>("expiresAt"))?.toLong()
                    val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 2
                    
                    val success = discoveryService.startBroadcast(
                        code = code,
                        hostIp = hostIp,
                        hostPort = hostPort,
                        roomId = roomId,
                        hostName = hostName,
                        expiresAt = expiresAt,
                        intervalSeconds = intervalSeconds
                    )
                    result.success(success)
                }
                "stopBroadcast" -> {
                    discoveryService.stopBroadcast()
                    result.success(true)
                }
                "getLocalIpAddress" -> {
                    val ip = discoveryService.getLocalIpAddress()
                    result.success(ip)
                }
                "hasLocalNetworkPermission" -> {
                    val hasPermission = discoveryService.hasLocalNetworkPermission()
                    result.success(hasPermission)
                }
                "requestLocalNetworkPermission" -> {
                    val hasPermission = discoveryService.hasLocalNetworkPermission()
                    result.success(hasPermission)
                }
                "startScan" -> {
                    val targetCode = call.argument<String>("code") ?: ""
                    val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 15

                    // Native→Flutter discovery events arrive from
                    // DiscoveryService's background scan/timeout threads.
                    // MethodChannel.invokeMethod is @UiThread and throws
                    // ("Methods marked with @UiThread must be executed on the
                    // main thread") when called off-main — this previously
                    // crashed right after MATCH FOUND. Always hop to the main
                    // looper before calling into Flutter, mirroring the
                    // audited notifyMessage/notifyState pattern.
                    fun invokeDiscoveryEventOnMainThread(event: Map<String, Any?>) {
                        Log.i(TAG, "[JOIN_TRACE] MainActivity: Dispatching discovery event to Android main thread (from thread=${Thread.currentThread().name})")
                        Handler(Looper.getMainLooper()).post {
                            Log.d(TAG, "[JOIN_TRACE] MainActivity: Invoking Flutter MethodChannel on main thread (thread=${Thread.currentThread().name})")
                            discoveryChannel.invokeMethod("onDiscoveryEvent", event)
                        }
                    }

                    discoveryService.startScan(
                        targetCode = targetCode,
                        timeoutSeconds = timeoutSeconds,
                        onAnnouncement = { announcement ->
                            invokeDiscoveryEventOnMainThread(mapOf(
                                "code" to announcement.code,
                                "hostIp" to announcement.hostIp,
                                "hostPort" to announcement.hostPort,
                                "protocolVersion" to announcement.protocolVersion,
                                "roomId" to announcement.roomId,
                                "hostName" to announcement.hostName,
                                "expiresAt" to announcement.expiresAt,
                                "isTimeout" to false
                            ))
                        },
                        onTimeout = {
                            invokeDiscoveryEventOnMainThread(mapOf(
                                "code" to "",
                                "hostIp" to "",
                                "hostPort" to 0,
                                "protocolVersion" to 0,
                                "roomId" to "",
                                "hostName" to "",
                                "isTimeout" to true
                            ))
                        }
                    )
                    result.success(true)
                }
                "stopScan" -> {
                    discoveryService.stopScan()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getDeviceInfo(): DeviceInfo {
        return DeviceInfo(
            platformName = "Android",
            osVersion = Build.VERSION.RELEASE,
            deviceModel = Build.MODEL,
            brand = Build.BRAND
        )
    }

    override fun getMonotonicTimeNanos(): Long {
        return SystemClock.elapsedRealtimeNanos()
    }

    // ---- Phase 5: AudioCapturePlatform implementation ----

    /**
     * Lazily construct the capture stack. The helper needs the Activity
     * (system permission dialogs), so it cannot be built before the
     * activity exists.
     */
    private fun ensureCaptureStack(): MediaProjectionHelper {
        mediaProjectionHelper?.let { return it }
        val helper = MediaProjectionHelper(this)
        mediaProjectionHelper = helper
        captureEngine = AudioCaptureEngine(
            context = this,
            scope = scope,
            helper = helper,
            stateMachine = captureStateMachine,
            notifyState = { state, metadata -> notifyCaptureState(state, metadata) },
            notifyError = { code, message -> notifyCaptureError(code, message) },
            notifyFrameStats = { stats -> notifyCaptureFrameStats(stats) },
            notifyNotificationUpdate = { isReceivingAudio, isSilent -> notifyCaptureNotificationUpdate(isReceivingAudio, isSilent) },
            onFrameCaptured = { data, byteCount, timestamp ->
                transportEngine?.onPcmFrame(data, byteCount, timestamp)
            },
        )
        return helper
    }

    override suspend fun requestCapturePermission(): CapturePermissionResult {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val message = "AudioPlaybackCapture requires Android 10 (API 29); " +
                "this device runs API ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})"
            Log.w(TAG, "[Capture] $message")
            return CapturePermissionResult(
                result = "DENIED",
                error = CaptureError(CaptureErrorClassifier.CAPTURE_UNSUPPORTED, message),
            )
        }

        val helper = ensureCaptureStack()

        if (!captureStateMachine.beginPermissionRequest()) {
            val message =
                "Cannot request capture permission from state ${captureStateMachine.state()}"
            Log.w(TAG, "[Capture] $message")
            return CapturePermissionResult(
                result = "DENIED",
                error = CaptureError(CaptureErrorClassifier.CAPTURE_START_FAILED, message),
            )
        }

        notifyCaptureState(CaptureSessionState.REQUESTING_PERMISSION.name, null)

        return try {
            val grant = helper.requestPermission()
            if (grant != null) {
                captureStateMachine.onPermissionResult(true)
                notifyCaptureState(CaptureSessionState.PERMISSION_GRANTED.name, null)
                CapturePermissionResult(result = "GRANTED", error = null)
            } else {
                captureStateMachine.onPermissionResult(false)
                notifyCaptureState(CaptureSessionState.PERMISSION_DENIED.name, null)
                CapturePermissionResult(
                    result = "DENIED",
                    error = CaptureError(
                        CaptureErrorClassifier.PERMISSION_DENIED,
                        "User declined MediaProjection consent (or RECORD_AUDIO)",
                    ),
                )
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            val classified = CaptureErrorClassifier.classify(e)
            Log.e(TAG, "[Capture] Permission flow failed: ${classified.message}", e)
            captureStateMachine.onPermissionFailed(classified.code, classified.message)
            notifyCaptureError(classified.code, classified.message)
            notifyCaptureState(CaptureSessionState.FAILED.name, null)
            CapturePermissionResult(
                result = "DENIED",
                error = CaptureError(classified.code, classified.message),
            )
        }
    }

    override suspend fun startCapture(): CaptureResult {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val message = "AudioPlaybackCapture requires Android 10 (API 29)"
            return CaptureResult(
                success = false,
                metadata = null,
                error = CaptureError(CaptureErrorClassifier.CAPTURE_UNSUPPORTED, message),
            )
        }
        ensureCaptureStack()
        val engine = captureEngine
            ?: return CaptureResult(
                success = false,
                metadata = null,
                error = CaptureError(
                    CaptureErrorClassifier.CAPTURE_START_FAILED,
                    "Capture engine unavailable",
                ),
            )
        return engine.start()
    }

    override suspend fun stopCapture() {
        // Safe to call when nothing is active (audio-api.md §11) — the
        // engine guards state transitions and discards unused grants.
        captureEngine?.stop()
    }

    override fun getCaptureState(): CaptureStateResult {
        val state = captureStateMachine.state()
        val metadata = captureEngine?.currentMetadata()
        return CaptureStateResult(
            state = CaptureState(state.name),
            metadata = metadata,
        )
    }

    // ---- Phase 8: AudioCapturePlatform streaming extensions ----

    override suspend fun startStreaming() {
        val metadata = captureEngine?.currentMetadata()
            ?: return
        transportEngine?.startStreaming(metadata)
    }

    override suspend fun stopStreaming() {
        transportEngine?.stopStreaming()
    }

    override fun getStreamingState(): StreamingState {
        return transportEngine?.getState() ?: StreamingState(state = "IDLE", metadata = null)
    }

    // ---- Phase 8: AudioReceivePlatform ----

    override fun getReceiveState(): ReceiveState {
        return receiveEngine?.getState() ?: ReceiveState(state = "IDLE", stats = null)
    }

    // ---- Phase 9: AudioOutputPlatform ----

    override fun getOutputState(): OutputState {
        return outputEngine?.getState() ?: OutputState(state = "ERROR", bufferedMs = 0)
    }

    override fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Before Android 6.0, no battery optimization exists
            return true
        }
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val result = powerManager.isIgnoringBatteryOptimizations(packageName)
        Log.d(TAG, "[BatteryOptimization] isIgnoringBatteryOptimizations() = $result")
        return result
    }

    override suspend fun requestIgnoreBatteryOptimizations() {
        Log.d(TAG, "[BatteryOptimization] requestIgnoreBatteryOptimizations() called")
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            Log.d(TAG, "[BatteryOptimization] Pre-Android M, skipping")
            return
        }
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        intent.data = Uri.parse("package:$packageName")
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        Log.d(TAG, "[BatteryOptimization] Launching intent: $intent")
        withContext(Dispatchers.Main) {
            try {
                startActivity(intent)
                Log.d(TAG, "[BatteryOptimization] Intent launched successfully")
            } catch (e: Exception) {
                Log.e(TAG, "[BatteryOptimization] Failed to launch intent", e)
            }
        }
    }

    // Activity-result plumbing for the capture permission flow.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        mediaProjectionHelper?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        mediaProjectionHelper?.onRuntimePermissionResult(requestCode, permissions, grantResults)
    }

    /**
     * Native→Flutter capture state events. Pigeon-generated FlutterApi methods
     * must be invoked on the Android main thread — same audited pattern as
     * notifyState/notifyMessage above (they previously crashed when called
     * from IO dispatchers).
     */
    private suspend fun notifyCaptureState(state: String, metadata: CaptureMetadata?) {
        withContext(Dispatchers.Main) {
            try {
                captureFlutterApi?.onCaptureStateChanged(state, metadata)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify capture state", e)
            }
        }
    }

    private suspend fun notifyCaptureError(errorCode: String, errorMessage: String) {
        withContext(Dispatchers.Main) {
            try {
                captureFlutterApi?.onCaptureError(errorCode, errorMessage)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify capture error", e)
            }
        }
    }

    private suspend fun notifyCaptureFrameStats(stats: FrameArrivalStats) {
        withContext(Dispatchers.Main) {
            try {
                captureFlutterApi?.onCaptureFramesReceived(stats)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify capture frame stats", e)
            }
        }
        // Store latest frame stats for notification updates when streaming state changes
        lastFrameReceivingAudio = stats.isReceivingAudio
        lastFrameIsSilent = stats.isSilent
    }

    private suspend fun notifyCaptureNotificationUpdate(isReceivingAudio: Boolean, isSilent: Boolean) {
        // Update the foreground service notification with live status.
        // This is a direct native call, not via Flutter.
        AudioCaptureService.updateNotification(isReceivingAudio, isSilent)
    }

    // ---- Phase 8: Stream state notifications ----

    private suspend fun notifyStreamState(state: String, metadata: StreamingMetadata?) {
        withContext(Dispatchers.Main) {
            try {
                captureFlutterApi?.onStreamStateChanged(state, metadata)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify stream state", e)
            }
        }
        // Also update the foreground notification to reflect streaming status
        AudioCaptureService.updateNotificationWithStreaming(
            lastFrameReceivingAudio,
            lastFrameIsSilent,
            state
        )
    }

    private suspend fun notifyStreamError(code: String, message: String) {
        withContext(Dispatchers.Main) {
            try {
                captureFlutterApi?.onStreamError(code, message)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify stream error", e)
            }
        }
    }

    private suspend fun notifyReceiveState(state: String, stats: ReceiveStats?) {
        withContext(Dispatchers.Main) {
            try {
                receiveFlutterApi?.onStreamStateChanged(state, stats)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify receive state", e)
            }
        }
    }

    private suspend fun notifyReceiveAudioLevel(peakAmplitude: Int, isSilent: Boolean) {
        withContext(Dispatchers.Main) {
            try {
                receiveFlutterApi?.onAudioLevelUpdate(peakAmplitude.toLong(), isSilent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify receive audio level", e)
            }
        }
    }

    private suspend fun notifyOutputState(state: String, errorCode: String?, errorMessage: String?) {
        withContext(Dispatchers.Main) {
            try {
                when (state) {
                    "OUTPUT_STARTED" -> outputFlutterApi?.onOutputStateChanged("PLAYING", 0)
                    "OUTPUT_STOPPED" -> outputFlutterApi?.onOutputStateChanged("STOPPED", 0)
                    "OUTPUT_UNDERRUN" -> outputFlutterApi?.onOutputStateChanged("UNDERRUN", 0)
                    "OUTPUT_ROUTE_CHANGED" -> outputFlutterApi?.onOutputStateChanged("ROUTE_CHANGED", 0)
                    "ERROR" -> {
                        outputFlutterApi?.onOutputStateChanged("ERROR", 0)
                        if (errorCode != null && errorMessage != null) {
                            outputFlutterApi?.onOutputError(errorCode, errorMessage)
                        }
                    }
                    else -> outputFlutterApi?.onOutputStateChanged(state, 0)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify output state", e)
            }
        }
    }

    override fun startHosting(port: Long): Boolean {
        if (port !in 1..65535) {
            Log.e(TAG, "Invalid hosting port: $port")
            scope.launch { notifyState("failed") }
            return false
        }
        val generation: Long
        synchronized(hostingLock) {
            // A duplicate Create Room tap can arrive before Flutter rebuilds the
            // disabled button. Keep the active listener alive; explicit disconnect()
            // is the normal path that permits a new hosting attempt.
            if (isHosting) {
                Log.w(TAG, "[HostLifecycle] Hosting already active (gen=$hostingGeneration); ignoring duplicate startHosting request")
                return true
            }

            generation = ++hostingGeneration
            isHosting = true
            Log.d(TAG, "[HostLifecycle] startHosting called, new hostingGeneration=$generation")
        }

        return try {
            val job = scope.launch {
                Log.d(TAG, "[HostLifecycle] Hosting coroutine started for generation=$generation")
                try {
                    notifyState("connecting")
                    Log.d(TAG, "[Connection] Starting TCP server on port $port")
                    val socket = ServerSocket(port.toInt())
                    synchronized(hostingLock) {
                        if (!isHosting || hostingGeneration != generation) {
                            Log.w(TAG, "[HostLifecycle] Hosting superseded before ServerSocket assigned (gen=$generation, currentGen=$hostingGeneration, isHosting=$isHosting)")
                            socket.close()
                            return@launch
                        }
                        serverSocket = socket
                    }
                    Log.d(TAG, "[Connection] TCP server listening on port $port")
                    Log.d(TAG, "[HostLifecycle] About to notifyState(connected) for listening state, gen=$generation")
                    notifyState("connected")
                    Log.d(TAG, "[HostLifecycle] Starting acceptConnection for generation=$generation")
                    acceptConnection(generation)
                    Log.d(TAG, "[HostLifecycle] acceptConnection returned normally for generation=$generation")
                } catch (e: CancellationException) {
                    Log.w(TAG, "[HostLifecycle] Hosting coroutine cancelled for generation=$generation")
                    throw e
                } catch (e: SocketException) {
                    Log.e(TAG, "[HostLifecycle] SocketException in hosting coroutine for generation=$generation", e)
                    handleHostingFailure(generation, "Failed to start hosting", e)
                } catch (e: Exception) {
                    Log.e(TAG, "[HostLifecycle] Exception in hosting coroutine for generation=$generation", e)
                    handleHostingFailure(generation, "Failed to start hosting", e)
                } finally {
                    Log.d(TAG, "[HostLifecycle] Hosting coroutine ending for generation=$generation")
                }
            }
            synchronized(hostingLock) {
                if (isHosting && hostingGeneration == generation) {
                    hostingJob = job
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule hosting", e)
            synchronized(hostingLock) {
                if (isHosting && hostingGeneration == generation) {
                    isHosting = false
                    ++hostingGeneration
                }
            }
            scope.launch { notifyState("failed") }
            false
        }
    }

    private fun isCurrentHosting(generation: Long): Boolean {
        return synchronized(hostingLock) {
            isHosting && hostingGeneration == generation
        }
    }

    private fun isCurrentConnection(generation: Long): Boolean {
        return synchronized(hostingLock) { connectionGeneration == generation }
    }

    private suspend fun handleHostingFailure(
        generation: Long,
        message: String,
        e: Exception,
    ) {
        val socketToClose = synchronized(hostingLock) {
            if (isHosting && hostingGeneration == generation) {
                Log.w(TAG, "[HostLifecycle] handleHostingFailure: marking hosting as failed, gen=$generation, currentGen=$hostingGeneration")
                isHosting = false
                ++hostingGeneration
                val socket = serverSocket
                serverSocket = null
                socket
            } else {
                Log.d(TAG, "[HostLifecycle] handleHostingFailure: superseded request ignored, gen=$generation, currentGen=$hostingGeneration, isHosting=$isHosting")
                null
            }
        }

        if (socketToClose == null) {
            Log.d(TAG, "Ignoring hosting failure from a superseded request")
            return
        }

        closeServerSocketSocket(socketToClose)
        Log.e(TAG, message, e)
        notifyState("failed")
    }

    private suspend fun acceptConnection(generation: Long) {
        val listeningSocket = synchronized(hostingLock) {
            serverSocket
        }
        Log.d(TAG, "[HostLifecycle] acceptConnection: waiting for connection on gen=$generation, socket=$listeningSocket")
        val socket = try {
            withContext(Dispatchers.IO) {
                listeningSocket?.accept()
            }
        } catch (e: CancellationException) {
            Log.w(TAG, "[HostLifecycle] acceptConnection cancelled for generation=$generation")
            throw e
        } catch (e: SocketException) {
            Log.w(TAG, "[HostLifecycle] SocketException in acceptConnection for generation=$generation", e)
            if (isCurrentHosting(generation)) {
                handleHostingFailure(generation, "Error accepting connection", e)
            } else {
                Log.d(TAG, "Hosting listener closed during shutdown")
            }
            return
        } catch (e: Exception) {
            Log.e(TAG, "[HostLifecycle] Exception in acceptConnection for generation=$generation", e)
            if (isCurrentHosting(generation)) {
                handleHostingFailure(generation, "Error accepting connection", e)
            } else {
                Log.d(TAG, "Ignoring accept failure from a superseded request")
            }
            return
        }

        Log.d(TAG, "[HostLifecycle] acceptConnection: accepted socket=$socket for generation=$generation")
        if (socket == null) {
            Log.w(TAG, "[HostLifecycle] acceptConnection: socket is null for generation=$generation")
            if (isCurrentHosting(generation)) {
                handleHostingFailure(
                    generation,
                    "Hosting socket is unavailable",
                    IllegalStateException("Hosting socket was closed before accept"),
                )
            } else {
                Log.d(TAG, "Hosting socket was closed during shutdown")
            }
            return
        }

        val shouldStartReading = synchronized(hostingLock) {
            if (!isHosting || hostingGeneration != generation) {
                Log.w(TAG, "[HostLifecycle] acceptConnection: hosting superseded after accept, gen=$generation, currentGen=$hostingGeneration, isHosting=$isHosting")
                false
            } else {
                connectionSocket = socket
                socket.setTcpNoDelay(true)
                true
            }
        }
        if (!shouldStartReading) {
            Log.d(TAG, "[HostLifecycle] acceptConnection: closing accepted socket due to superseded hosting")
            socket.close()
            return
        }

        Log.d(TAG, "[HostLifecycle] acceptConnection: about to notifyState(connected) for accepted connection, gen=$generation")
        startReading(socket)
        notifyState("connected")
        startHeartbeat()
    }

    override fun connectToHost(ipAddress: String, port: Long): Boolean {
        if (port !in 1..65535) {
            Log.e(TAG, "Invalid connect port: $port")
            scope.launch { notifyState("failed") }
            return false
        }
        // Store for potential reconnection
        lastKnownHostIp = ipAddress
        lastKnownHostPort = port.toInt()
        isReconnecting = false
        reconnectAttempts = 0
        return try {
            stopAll()
            val generation: Long
            synchronized(hostingLock) {
                generation = ++connectionGeneration
            }
            scope.launch {
                notifyState("connecting")
                Log.d(TAG, "[Connection] Attempting TCP connect to $ipAddress:$port")
                val socket = Socket()
                try {
                    // Bounded connect timeout: the OS default can block for
                    // minutes, outliving Dart's 10s handshake timeout.
                    socket.connect(InetSocketAddress(ipAddress, port.toInt()), CONNECT_TIMEOUT_MS)
                    socket.setTcpNoDelay(true)
                } catch (e: Exception) {
                    Log.e(TAG, "[Connection] TCP connect failed to $ipAddress:$port", e)
                    if (isCurrentConnection(generation)) {
                        val errorCode = when (e) {
                            is java.net.ConnectException -> "CONNECTION_REFUSED"
                            is java.net.SocketTimeoutException -> "CONNECTION_TIMEOUT"
                            is java.net.UnknownHostException -> "UNKNOWN_HOST"
                            is java.net.NoRouteToHostException -> "NETWORK_UNREACHABLE"
                            is java.net.SocketException -> {
                                // Check for EHOSTUNREACH / no route to host
                                if (e.message?.contains("EHOSTUNREACH", ignoreCase = true) == true ||
                                    e.message?.contains("no route", ignoreCase = true) == true ||
                                    e.message?.contains("unreachable", ignoreCase = true) == true) {
                                    "NETWORK_UNREACHABLE"
                                } else {
                                    "SOCKET_ERROR"
                                }
                            }
                            else -> "CONNECTION_FAILED"
                        }
                        val errorMessage = "${e.javaClass.simpleName}: ${e.message}"
                        notifyConnectionError(errorCode, errorMessage)
                        notifyState("failed")
                    }
                    runCatching { socket.close() }
                    return@launch
                }

                // A disconnect or a newer attempt may have superseded this
                // connect while it was in flight; never surface a stale
                // connection or notifications from it.
                if (!isCurrentConnection(generation)) {
                    runCatching { socket.close() }
                    return@launch
                }

                synchronized(hostingLock) {
                    if (isCurrentConnection(generation)) {
                        clientSocket = socket
                        connectionSocket = socket
                    }
                }
                if (!isCurrentConnection(generation)) {
                    runCatching { socket.close() }
                    return@launch
                }
                Log.d(TAG, "[Connection] TCP connected to $ipAddress:$port")
                startReading(socket)
                notifyState("connected")
                startHeartbeat()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect", e)
            scope.launch { notifyState("failed") }
            false
        }
    }

    override fun sendMessage(message: String): Boolean {
        return buildAndEnqueueJson(message)
    }

    override fun sendChatMessage(text: String): Boolean {
        // Dart constructs the full ProtocolMessage.chat JSON and passes it to sendChatMessage
        Log.d(TAG, "[WriterDebug] sendChatMessage: text length=${text.length}")
        return buildAndEnqueueJson(text)
    }

    override fun sendProtocolMessage(message: String): Boolean {
        Log.d(TAG, "[WriterDebug] sendProtocolMessage: messageType preview = ${message.take(minOf(200, message.length))}")
        return buildAndEnqueueJson(message)
    }

    override fun disconnect() {
        Log.d(TAG, "[HostLifecycle] disconnect() called")
        stopAll()
        scope.launch { notifyState("disconnected") }
    }

    override fun getLocalIpAddress(): String {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (networkInterface.isLoopback || !networkInterface.isUp) continue
                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (address is Inet4Address && !address.isLoopbackAddress) {
                        return address.hostAddress ?: "127.0.0.1"
                    }
                }
            }
            "127.0.0.1"
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get local IP", e)
            "127.0.0.1"
        }
    }

    override suspend fun setHeartbeatConfig(intervalMs: Long, timeoutMs: Long) {
        Log.d(TAG, "[Heartbeat] Configuring heartbeat: intervalMs=$intervalMs, timeoutMs=$timeoutMs")
        heartbeatIntervalMs = intervalMs
        heartbeatTimeoutMs = timeoutMs
        // Restart heartbeat if already running
        if (connectionSocket != null && connectionSocket!!.isConnected && !connectionSocket!!.isClosed) {
            startHeartbeat()
        }
    }

    override suspend fun reconnectToHost(ipAddress: String, port: Long): Boolean {
        Log.d(TAG, "[Reconnection] reconnectToHost called: $ipAddress:$port")
        if (isHosting) {
            Log.w(TAG, "[Reconnection] Cannot reconnect while hosting")
            return false
        }
        synchronized(hostingLock) {
            lastKnownHostIp = ipAddress
            lastKnownHostPort = port.toInt()
            isReconnecting = true
            reconnectAttempts = 0
        }
        scope.launch {
            attemptReconnect()
        }
        return true
    }

    private suspend fun attemptReconnect() {
        val ip: String
        val port: Int
        synchronized(hostingLock) {
            ip = lastKnownHostIp ?: return
            port = lastKnownHostPort
        }
        while (true) {
            var shouldContinue = false
            synchronized(hostingLock) {
                if (!isReconnecting || reconnectAttempts >= maxReconnectAttempts) {
                    return
                }
                reconnectAttempts++
                shouldContinue = true
            }
            if (!shouldContinue) return

            Log.d(TAG, "[Reconnection] Attempt $reconnectAttempts/$maxReconnectAttempts to $ip:$port")
            notifyState("reconnecting")
            val socket = Socket()
            try {
                socket.connect(InetSocketAddress(ip, port), CONNECT_TIMEOUT_MS)
            } catch (e: Exception) {
                Log.w(TAG, "[Reconnection] Attempt $reconnectAttempts failed: ${e.javaClass.simpleName}: ${e.message}")
                runCatching { socket.close() }
                var shouldRetry = false
                synchronized(hostingLock) {
                    if (isReconnecting && reconnectAttempts < maxReconnectAttempts) {
                        shouldRetry = true
                    }
                }
                if (!shouldRetry) return
                // Wait before retry with exponential backoff (capped)
                val delayMs = minOf(1000L * (1 shl (reconnectAttempts - 1)), 10000L)
                try {
                    delay(delayMs)
                } catch (e: CancellationException) {
                    return
                } catch (e: Exception) {
                    Log.e(TAG, "[Reconnection] Delay interrupted", e)
                    return
                }
                continue
            }

            var shouldProceed = false
            synchronized(hostingLock) {
                if (isReconnecting) {
                    clientSocket = socket
                    connectionSocket = socket
                    shouldProceed = true
                }
            }
            if (!shouldProceed) {
                runCatching { socket.close() }
                return
            }

            Log.d(TAG, "[Reconnection] TCP reconnected to $ip:$port")
            notifyState("connected")
            startReading(socket)
            startHeartbeat()
            synchronized(hostingLock) {
                isReconnecting = false
                reconnectAttempts = 0
            }
            return
        }
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        lastHeartbeatReceivedMs = 0L // Initialize to 0 - will be set when first heartbeat received
        heartbeatJob = scope.launch {
            Log.d(TAG, "[Heartbeat] Starting heartbeat with interval=${heartbeatIntervalMs}ms, timeout=${heartbeatTimeoutMs}ms")
            while (connectionSocket != null && connectionSocket!!.isConnected && !connectionSocket!!.isClosed) {
                // Check timeout at the START of each iteration
                val now = System.currentTimeMillis()
                if (lastHeartbeatReceivedMs > 0) {
                    val timeSinceLastHeartbeat = now - lastHeartbeatReceivedMs
                    if (timeSinceLastHeartbeat > heartbeatTimeoutMs) {
                        Log.w(TAG, "[Heartbeat] Timeout: no heartbeat for ${timeSinceLastHeartbeat}ms (threshold=${heartbeatTimeoutMs}ms)")
                        handleHeartbeatTimeout()
                        return@launch
                    }
                }

                // Send PING
                sendPing()

                // Wait for next interval using coroutine delay
                try {
                    delay(heartbeatIntervalMs)
                } catch (e: CancellationException) {
                    return@launch
                } catch (e: Exception) {
                    Log.e(TAG, "[Heartbeat] Delay interrupted", e)
                    return@launch
                }
            }
            Log.d(TAG, "[Heartbeat] Heartbeat loop ended (socket closed or disconnected)")
        }
    }

    private fun sendPing() {
        val socket = connectionSocket ?: return
        val participantId = currentParticipantId ?: getFallbackDeviceId()
        val pingJson = JSONObject().apply {
            put("protocolVersion", 1)
            put("messageId", java.util.UUID.randomUUID().toString())
            put("messageType", "PING")
            put("senderId", participantId)
            put("generation", 0)
            put("timestamp", System.currentTimeMillis())
        }.toString()
        Log.d(TAG, "[Heartbeat] Sent PING")
        buildAndEnqueueJson(pingJson)
    }

    private suspend fun handleHeartbeatTimeout() {
        Log.w(TAG, "[Heartbeat] Handling heartbeat timeout")
        heartbeatJob?.cancel()
        readerJob?.cancel()
        readerJob = null
        if (isHosting) {
            // Host: notify about participant timeout
            notifyConnectionError("HEARTBEAT_TIMEOUT", "Participant heartbeat timeout")
            notifyState("disconnected")
        } else {
            // Participant: initiate reconnection
            if (!isReconnecting) {
                isReconnecting = true
                reconnectAttempts = 0
                scope.launch { attemptReconnect() }
            }
        }
        // Close the dead connection
        try {
            connectionSocket?.close()
        } catch (e: Exception) {}
        connectionSocket = null
    }

    private fun onHeartbeatReceived() {
        lastHeartbeatReceivedMs = System.currentTimeMillis()
    }

    private fun handlePong() {
        onHeartbeatReceived()
    }

    private fun getFallbackDeviceId(): String {
        // Use a stable device identifier - in practice this would be the participantId
        // For now, generate a simple identifier based on the device
        return "android-${Build.MODEL}-${Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)}"
    }

    private fun isHeartbeatMessage(message: String): Boolean {
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            return messageType == "PING" || messageType == "PONG"
        } catch (e: Exception) {
            return false
        }
    }

    private fun handleHeartbeatMessage(message: String) {
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            if (messageType == "PING") {
                Log.d(TAG, "[Heartbeat] Received PING, sending PONG")
                sendPong(json)
            } else if (messageType == "PONG") {
                Log.d(TAG, "[Heartbeat] Received PONG")
                onHeartbeatReceived()
            }
        } catch (e: Exception) {
            Log.e(TAG, "[Heartbeat] Failed to parse heartbeat message", e)
        }
    }

    // ---- Phase 8: Audio message handling ----

    private fun isAudioMessage(message: String): Boolean {
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            return messageType == "AUDIO_PACKET" ||
                   messageType == "AUDIO_STREAM_INFO" ||
                   messageType == "AUDIO_STREAM_START" ||
                   messageType == "AUDIO_STREAM_STOP"
        } catch (e: Exception) {
            return false
        }
    }

    private fun handleAudioMessage(message: String) {
        packetsParsed.incrementAndGet()
        lastPacketParsedTimestampNanos.set(SystemClock.elapsedRealtimeNanos())
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            val sessionId = json.optString("sessionId", "")
            val generation = json.optLong("generation", 0)

            when (messageType) {
                "AUDIO_STREAM_INFO" -> {
                    val payload = json.optJSONObject("payload")
                    if (payload != null) {
                        val sampleRate = payload.optInt("sampleRate", 0)
                        val channelCount = payload.optInt("channelCount", 0)
                        val startedAtNanos = payload.optLong("startedAtNanos", 0)
                        Log.i(TAG, "[AudioTransport] Received AUDIO_STREAM_INFO: sr=$sampleRate ch=$channelCount gen=$generation")
                        receiveEngine?.onStreamInfo(sessionId, generation, sampleRate, channelCount)
                        outputEngine?.onStreamInfo(generation, sampleRate, channelCount)
                    }
                }
                "AUDIO_STREAM_START" -> {
                    Log.i(TAG, "[AudioTransport] Received AUDIO_STREAM_START: gen=$generation")
                    scope.launch { receiveEngine?.onStreamStart(generation) }
                    scope.launch { outputEngine?.onStreamStart(generation) }
                }
                "AUDIO_STREAM_STOP" -> {
                    Log.i(TAG, "[AudioTransport] Received AUDIO_STREAM_STOP: gen=$generation")
                    scope.launch { receiveEngine?.onStreamStop(generation) }
                    scope.launch { outputEngine?.onStreamStop(generation) }
                }
                "AUDIO_PACKET" -> {
                    val payload = json.optJSONObject("payload")
                    if (payload != null) {
                        val base64Data = payload.optString("data", "")
                        val sequence = payload.optInt("sequence", 0)
                        val captureTimestamp = payload.optLong("captureTimestamp", 0)
                        if (base64Data.isNotEmpty()) {
                            val wireBytes = Base64.decode(base64Data, Base64.NO_WRAP)
                            val packet = AudioPacket.fromByteArray(wireBytes)
                            packet?.let {
                                // Override sequence and timestamp from envelope (source of truth)
                                val updatedPacket = it.copy(
                                    sequenceNumber = sequence,
                                    captureTimestampNanos = captureTimestamp,
                                )
                                receiveEngine?.onAudioPacket(updatedPacket)
                                audioPacketsDispatched.incrementAndGet()
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "[AudioTransport] Failed to handle audio message", e)
            packetsParseFailed.incrementAndGet()
        }
    }

    private fun sendPong(pingJson: JSONObject) {
        val socket = connectionSocket ?: return
        val participantId = currentParticipantId ?: getFallbackDeviceId()
        val originalMessageId = pingJson.optString("messageId", "")
        val pongJson = JSONObject().apply {
            put("protocolVersion", 1)
            put("messageId", java.util.UUID.randomUUID().toString())
            put("messageType", "PONG")
            put("senderId", participantId)
            put("generation", 0)
            put("timestamp", System.currentTimeMillis())
            put("payload", JSONObject().put("originalMessageId", originalMessageId))
        }.toString()
        Log.d(TAG, "[Heartbeat] Sent PONG")
        buildAndEnqueueJson(pongJson)
    }

    private fun startReading(socket: Socket) {
        readerJob?.cancel()
        val generation: Long
        synchronized(hostingLock) {
            generation = ++connectionGeneration
        }
        Log.d(TAG, "[HostLifecycle] startReading: starting reader for generation=$generation (connectionGeneration=$connectionGeneration)")
        Log.d(TAG, "[ReaderDebug] startReading: socket=$socket, socket.isConnected=${socket.isConnected}, socket.isClosed=${socket.isClosed}")
        
        // Reset diagnostic counters for new connection
        networkBytesReceived.set(0)
        networkFramesDecoded.set(0)
        lastNetworkReceiveTimestampNanos.set(0)
        packetsParsed.set(0)
        packetsParseFailed.set(0)
        audioPacketsDispatched.set(0)
        lastPacketParsedTimestampNanos.set(0)
        
        // Start network diagnostics reporter
        networkDiagJob?.cancel()
        networkDiagJob = scope.launch(Dispatchers.IO) { networkDiagnosticsReporter() }

        // Start single-writer serialization coroutine
        writerJob?.cancel()
        writerChannel = kotlinx.coroutines.channels.Channel<ByteArray>(capacity = 200)
        writerJob = scope.launch(Dispatchers.IO) { writerLoop(socket) }

        readerJob = scope.launch {
            val inputStream = socket.getInputStream()
            Log.d(TAG, "[ReaderDebug] startReading: got inputStream=$inputStream")
            val buffer = ByteArray(4096)
            val decoder = FrameDecoder(
                onFrameStarted = {
                    Log.d(TAG, "Starting new frame read: headerBytesRead=0, payloadBytesRead=0")
                },
                onFrameCompleted = { payloadLength ->
                    Log.d(TAG, "Frame read complete: payloadLength=$payloadLength, payloadBytesRead=0")
                },
                onInvalidLength = { frameLength ->
                    Log.w(TAG, "Invalid frame length: $frameLength, resetting frame state")
                },
            )

            try {
                while (socket.isConnected && !socket.isClosed) {
                    Log.d(TAG, "[ReaderDebug] BEFORE read: socket.isConnected=${socket.isConnected}, socket.isClosed=${socket.isClosed}")
                    val bytesRead = withContext(Dispatchers.IO) {
                        inputStream.read(buffer)
                    }
                    Log.d(TAG, "[ReaderDebug] AFTER read: bytesRead=$bytesRead")
                    if (bytesRead == -1) {
                        Log.d(TAG, "[ReaderDebug] read returned -1 (EOF), breaking")
                        break
                    }
                    if (bytesRead == 0) {
                        Log.d(TAG, "[ReaderDebug] read returned 0, continuing")
                        continue
                    }

                    networkBytesReceived.addAndGet(bytesRead.toLong())
                    lastNetworkReceiveTimestampNanos.set(SystemClock.elapsedRealtimeNanos())

                    val messages = decoder.accept(buffer, 0, bytesRead)
                    for (message in messages) {
                        networkFramesDecoded.incrementAndGet()
                        Log.d(TAG, "[ReaderDebug] Decoded message: ${message.take(minOf(200, message.length))}...")
                        // Handle heartbeat messages locally
                        if (isHeartbeatMessage(message)) {
                            handleHeartbeatMessage(message)
                        } else if (isAudioMessage(message)) {
                            handleAudioMessage(message)
                        } else {
                            notifyMessage(message)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "[ReaderDebug] Exception during read: ${e.javaClass.simpleName}: ${e.message}", e)
            }
            // Superseded readers (stopAll() bumped the generation) must not
            // emit a stale "disconnected" after a new attempt's "connecting".
            if (isCurrentConnection(generation)) {
                Log.d(TAG, "[HostLifecycle] startReading: reader ending, notifying disconnected for generation=$generation")
                notifyState("disconnected")
            } else {
                Log.d(TAG, "[HostLifecycle] startReading: reader ending, superseded (gen=$generation, currentGen=$connectionGeneration), not notifying disconnected")
            }
        }
    }

    private fun closeServerSocketSocket(socket: ServerSocket?) {
        try {
            socket?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing hosting socket", e)
        }
    }

    private fun closeServerSocket() {
        val socket = synchronized(hostingLock) {
            val current = serverSocket
            serverSocket = null
            current
        }
        closeServerSocketSocket(socket)
    }

    private fun stopAll() {
        Log.d(TAG, "[HostLifecycle] stopAll() called, current hostingGeneration=$hostingGeneration, isHosting=$isHosting")
        val job: Job?
        synchronized(hostingLock) {
            job = hostingJob
            hostingJob = null
            ++hostingGeneration
            ++connectionGeneration
            isHosting = false
            lastKnownHostIp = null
            lastKnownHostPort = 8765
            currentParticipantId = null
            Log.d(TAG, "[HostLifecycle] stopAll: incremented hostingGeneration to $hostingGeneration, connectionGeneration to $connectionGeneration")
        }
        job?.cancel()
        Log.d(TAG, "[HostLifecycle] stopAll: cancelled hostingJob")

        heartbeatJob?.cancel()
        heartbeatJob = null
        isReconnecting = false
        reconnectAttempts = 0

        readerJob?.cancel()
        readerJob = null
        writerJob?.cancel()
        writerJob = null
        try {
            writerChannel.close()
        } catch (e: Exception) {}
        networkDiagJob?.cancel()
        networkDiagJob = null
        try {
            connectionSocket?.close()
        } catch (e: Exception) {}
        connectionSocket = null
        try {
            clientSocket?.close()
        } catch (e: Exception) {}
        clientSocket = null
        closeServerSocket()
        Log.d(TAG, "[HostLifecycle] stopAll: completed")
    }

    private suspend fun notifyMessage(message: String) {
        // Pigeon-generated NetworkFlutterApi methods are annotated @UiThread and
        // throw RuntimeException ("Methods marked with @UiThread must be executed
        // on the main thread") when invoked from our IO/Default dispatcher
        // coroutines. Always hop to Dispatchers.Main before calling into Flutter.
        withContext(Dispatchers.Main) {
            try {
                flutterApi?.onMessageReceived(message)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify message", e)
            }
        }
    }

    private suspend fun notifyState(state: String) {
        // See notifyMessage: NetworkFlutterApi is @UiThread and must be called
        // on the Android main thread, not from coroutine worker threads.
        Log.d(TAG, "[HostLifecycle] notifyState($state) called")
        withContext(Dispatchers.Main) {
            try {
                flutterApi?.onConnectionStateChanged(state)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify state", e)
            }
        }
    }

    private suspend fun notifyConnectionError(errorCode: String, errorMessage: String) {
        // Pigeon-generated NetworkFlutterApi methods are annotated @UiThread and
        // throw RuntimeException ("Methods marked with @UiThread must be executed
        // on the main thread") when invoked from our IO/Default dispatcher
        // coroutines — this previously crashed the app on every real TCP
        // connection failure. Always hop to Dispatchers.Main before calling
        // into Flutter.
        withContext(Dispatchers.Main) {
            try {
                flutterApi?.onConnectionError(errorCode, errorMessage)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify connection error", e)
            }
        }
    }

    override fun onDestroy() {
        discoveryService.dispose()
        super.onDestroy()
    }

    /** Periodic network diagnostics reporter for pipeline tracing (BUG #3). */
    private suspend fun networkDiagnosticsReporter() {
        try {
            while (connectionSocket != null && connectionSocket!!.isConnected && !connectionSocket!!.isClosed) {
                kotlinx.coroutines.delay(2000)
                val now = SystemClock.elapsedRealtimeNanos()
                val lastWriteAgeMs = if (lastSocketWriteTimestampNanos.get() > 0) {
                    (now - lastSocketWriteTimestampNanos.get()) / 1_000_000
                } else -1L
                val lastReceiveAgeMs = if (lastNetworkReceiveTimestampNanos.get() > 0) {
                    (now - lastNetworkReceiveTimestampNanos.get()) / 1_000_000
                } else -1L
                val lastParseAgeMs = if (lastPacketParsedTimestampNanos.get() > 0) {
                    (now - lastPacketParsedTimestampNanos.get()) / 1_000_000
                } else -1L
                Log.i(
                    TAG,
                    "[DIAG] Socket: writesAttempted=${socketWritesAttempted.get()} " +
                        "writesSucceeded=${socketWritesSucceeded.get()} writesFailed=${socketWritesFailed.get()} " +
                        "bytesWritten=${socketBytesWritten.get()} lastWriteAgeMs=$lastWriteAgeMs"
                )
                Log.i(
                    TAG,
                    "[DIAG] Network: bytesReceived=${networkBytesReceived.get()} " +
                        "framesDecoded=${networkFramesDecoded.get()} lastReceiveAgeMs=$lastReceiveAgeMs"
                )
                Log.i(
                    TAG,
                    "[DIAG] Parser: packetsParsed=${packetsParsed.get()} " +
                        "packetsParseFailed=${packetsParseFailed.get()} " +
                        "audioPacketsDispatched=${audioPacketsDispatched.get()} " +
                        "lastParseAgeMs=$lastParseAgeMs"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Network diagnostics reporter failed", e)
        }
    }

    /** Single-writer loop: serializes all TCP frame writes to prevent interleaving (BUG #3 fix). */
    private suspend fun writerLoop(socket: Socket) {
        val outputStream = socket.getOutputStream()
        try {
            for (frame in writerChannel) {
                try {
                    outputStream.write(frame)
                    outputStream.flush()
                    socketWritesSucceeded.incrementAndGet()
                    socketBytesWritten.addAndGet(frame.size.toLong())
                    lastSocketWriteTimestampNanos.set(SystemClock.elapsedRealtimeNanos())
                } catch (e: Exception) {
                    Log.e(TAG, "Writer loop frame write failed", e)
                    socketWritesFailed.incrementAndGet()

                    try {
                        socket.close()
                    } catch (e2: Exception) {
                        Log.e(TAG, "Failed to close socket after writer failure", e2)
                    }

                    writerChannel.close()
                    break
                }
            }
        } catch (e: kotlinx.coroutines.channels.ClosedReceiveChannelException) {
            // Normal shutdown
        } catch (e: Exception) {
            Log.e(TAG, "Writer loop failed", e)
        }
    }

    /** Enqueue a complete frame for serialized writing. Returns true if enqueued. */
    private fun enqueueFrame(frame: ByteArray): Boolean {
        val socket = connectionSocket ?: return false
        val channel = writerChannel
        socketWritesAttempted.incrementAndGet()

        return try {
            val result = channel.trySend(frame)
            if (result.isSuccess) {
                true
            } else {
                // Channel full - this is the primary packet loss source under load
                socketWritesFailed.incrementAndGet()
                Log.w(TAG, "Writer queue full, dropping frame (capacity=200)")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enqueue frame", e)
            socketWritesFailed.incrementAndGet()
            false
        }
    }

    /** Helper to construct a framed payload and enqueue it. */
    private fun buildAndEnqueueFrame(payload: ByteArray): Boolean {
        val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
        frame[0] = (payload.size shr 24).toByte()
        frame[1] = (payload.size shr 16).toByte()
        frame[2] = (payload.size shr 8).toByte()
        frame[3] = payload.size.toByte()
        System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
        return enqueueFrame(frame)
    }

    /** Helper to construct a framed JSON string and enqueue it. */
    private fun buildAndEnqueueJson(jsonString: String): Boolean {
        val payload = jsonString.toByteArray(StandardCharsets.UTF_8)
        return buildAndEnqueueFrame(payload)
    }
}
