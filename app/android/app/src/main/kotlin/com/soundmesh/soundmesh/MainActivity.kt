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
import com.soundmesh.soundmesh.discovery.DiscoveryService
import com.soundmesh.soundmesh.output.AudioOutputEngine
import com.soundmesh.soundmesh.transport.AudioPacket
import com.soundmesh.soundmesh.transport.AudioReceiveEngine
import com.soundmesh.soundmesh.transport.AudioTransportEngine
import com.soundmesh.soundmesh.ReceiveState
import com.soundmesh.soundmesh.ReceiveStats
import com.soundmesh.soundmesh.OutputState
import com.soundmesh.soundmesh.ScheduleResult
import com.soundmesh.soundmesh.StreamingMetadata
import com.soundmesh.soundmesh.StreamingState
import com.soundmesh.soundmesh.TimeSyncResponse
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
    AudioCapturePlatform, AudioReceivePlatform, AudioOutputPlatform, PipelinePlatform {
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
    private val scope = CoroutineScope(Job() + Dispatchers.IO)

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
    // Per-participant writer channels for independent backpressure (HOST side)
    // Keyed by connectionId (unique per TCP connection) to prevent stale connection cleanup races
    private val participantConnections = mutableMapOf<String, ParticipantConnection>()
    // Maps participantId -> connectionId for the currently active connection
    private val participantIdToConnectionId = mutableMapOf<String, String>()
    private val participantConnectionsLock = Any()

    // Single-writer for participant-side connection (when this device is a PARTICIPANT)
    @Volatile private var writerChannel = kotlinx.coroutines.channels.Channel<ByteArray>(capacity = 100)
    private var writerJob: Job? = null

    data class ParticipantConnection(
        val connectionId: String,
        val socket: Socket,
        val writerChannel: kotlinx.coroutines.channels.Channel<ByteArray>,
        val writerJob: Job?,
        val readerJob: Job?,
        val participantId: String,
        val heartbeatJob: Job? = null,
        val lastHeartbeatReceivedMs: AtomicLong = AtomicLong(0)
    )

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

    // ---- Phase 10: pipeline coordination ----
    private var pipelineState = "IDLE"
    private var pipelineGeneration = 0L
    private var pipelineFlutterApi: PipelineFlutterApi? = null
    private var pipelineWatchdogJob: Job? = null
    private var lastAudioActivityNanos = AtomicLong(0)
    private val PIPELINE_STALL_THRESHOLD_MS = 5000L
    
    // ---- Sync state tracking for preparation barrier ----
    @Volatile private var syncState = "UNKNOWN"
    @Volatile private var syncOffsetMs = 0.0
    @Volatile private var syncDriftMsPerSecond: Double? = null

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

        // ---- Phase 10: PipelinePlatform ----
        PipelinePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        pipelineFlutterApi = PipelineFlutterApi(flutterEngine.dartExecutor.binaryMessenger)

        // Create transport engines
        transportEngine = AudioTransportEngine(
            context = this,
            scope = scope,
            initialSenders = getParticipantSenders(),
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
            getSyncState = { this.getSyncState() },
            getOffsetEstimateMs = { this.syncOffsetMs },
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
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
                recordAudioActivity()
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
                    Log.d(TAG, "[HostLifecycle] Starting acceptConnectionLoop for generation=$generation")
                    acceptConnectionLoop(generation)
                    Log.d(TAG, "[HostLifecycle] acceptConnectionLoop returned normally for generation=$generation")
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

    private suspend fun acceptConnectionLoop(generation: Long) {
        val listeningSocket = synchronized(hostingLock) {
            serverSocket
        }
        Log.d(TAG, "[HostLifecycle] acceptConnectionLoop: starting for generation=$generation")
        
        while (true) {
            val socket = try {
                withContext(Dispatchers.IO) {
                    listeningSocket?.accept()
                }
            } catch (e: CancellationException) {
                Log.w(TAG, "[HostLifecycle] acceptConnectionLoop cancelled for generation=$generation")
                throw e
            } catch (e: SocketException) {
                Log.w(TAG, "[HostLifecycle] SocketException in acceptConnectionLoop for generation=$generation", e)
                if (isCurrentHosting(generation)) {
                    handleHostingFailure(generation, "Error accepting connection", e)
                } else {
                    Log.d(TAG, "Hosting listener closed during shutdown")
                }
                return
            } catch (e: Exception) {
                Log.e(TAG, "[HostLifecycle] Exception in acceptConnectionLoop for generation=$generation", e)
                if (isCurrentHosting(generation)) {
                    handleHostingFailure(generation, "Error accepting connection", e)
                } else {
                    Log.d(TAG, "Ignoring accept failure from a superseded request")
                }
                return
            }

            if (socket == null) {
                Log.w(TAG, "[HostLifecycle] acceptConnectionLoop: socket is null for generation=$generation")
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
                    Log.w(TAG, "[HostLifecycle] acceptConnectionLoop: hosting superseded after accept, gen=$generation, currentGen=$hostingGeneration, isHosting=$isHosting")
                    false
                } else {
                    socket.setTcpNoDelay(true)
                    true
                }
            }
            if (!shouldStartReading) {
                Log.d(TAG, "[HostLifecycle] acceptConnectionLoop: closing accepted socket due to superseded hosting")
                socket.close()
                continue
            }

            Log.d(TAG, "[HostLifecycle] acceptConnectionLoop: accepted socket=$socket for generation=$generation")
            // Start reading for this participant - participantId will be set after HELLO
            startReadingForParticipant(socket, generation)
            notifyState("connected")
            // Heartbeat is now per-participant, started after HELLO
        }
    }

    private fun startReadingForParticipant(socket: Socket, generation: Long) {
        // Participant ID will be set after HELLO is received
        // For now, create a temporary connection entry with a placeholder ID
        val tempParticipantId = "pending-${System.currentTimeMillis()}"
        val writerChannel = kotlinx.coroutines.channels.Channel<ByteArray>(capacity = 200)
        
        val readerJob = scope.launch {
            val inputStream = socket.getInputStream()
            Log.d(TAG, "[ReaderDebug] startReadingForParticipant: got inputStream=$inputStream for $tempParticipantId")
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
                        // Handle HELLO messages locally to extract participantId AND forward to Flutter
                        if (isHelloMessage(message)) {
                            handleHelloMessage(message, tempParticipantId)
                            notifyMessage(message)
                        } else if (isHeartbeatMessage(message)) {
                            handleHeartbeatMessage(message)
                        } else if (isSyncMessage(message)) {
                            handleSyncMessage(message)
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
            // Cleanup on disconnect - use the current connectionId from the connection
            synchronized(participantConnectionsLock) {
                val conn = participantConnections[tempParticipantId] 
                    ?: participantConnections.values.firstOrNull { it.socket == socket }
                val currentConnectionId = conn?.connectionId ?: tempParticipantId
                cleanupParticipantConnectionById(currentConnectionId, "disconnected")
            }
        }
        
        val writerJob = scope.launch(Dispatchers.IO) { writerLoop(socket, writerChannel) }
        
        // Store the connection with a unique connectionId (not participantId)
        val connectionId = java.util.UUID.randomUUID().toString()
        synchronized(participantConnectionsLock) {
            participantConnections[connectionId] = ParticipantConnection(
                connectionId = connectionId,
                socket = socket,
                writerChannel = writerChannel,
                writerJob = writerJob,
                readerJob = readerJob,
                participantId = tempParticipantId
            )
        }
    }

    // Update existing connection with heartbeat job when participantId is assigned
    private fun startParticipantHeartbeat(participantId: String) {
        synchronized(participantConnectionsLock) {
            // Find the connectionId for this participant
            val connectionId = participantIdToConnectionId[participantId]
            connectionId?.let { connId ->
                participantConnections[connId]?.let { conn ->
                    if (conn.heartbeatJob == null) {
                        val heartbeatJob = startPerParticipantHeartbeat(participantId, conn.socket)
                        participantConnections[connId] = conn.copy(heartbeatJob = heartbeatJob)
                        Log.d(TAG, "[Heartbeat] Started per-participant heartbeat for $participantId")
                    }
                }
            }
        }
    }

    private fun updateParticipantId(oldId: String, newId: String) {
        synchronized(participantConnectionsLock) {
            // Find connection by oldId (which could be a temp ID or previous participantId)
            val connEntry = participantConnections.entries.firstOrNull { it.value.participantId == oldId }
            connEntry?.let { entry ->
                val conn = entry.value
                val connectionId = conn.connectionId
                
                // If there's already an active connection for newId, it will be replaced
                // The old connection will self-cleanup via EOF/timeout
                val oldConnectionId = participantIdToConnectionId[newId]
                if (oldConnectionId != null && oldConnectionId != connectionId) {
                    Log.d(TAG, "[HostLifecycle] Replacing existing connection for participant $newId: $oldConnectionId -> $connectionId")
                    // Don't cancel the old connection here - it will self-cleanup
                }
                
                // Update the connection's participantId
                participantConnections[connectionId] = conn.copy(participantId = newId)
                
                // Update the participantId -> connectionId mapping
                participantIdToConnectionId[newId] = connectionId
                participantIdToConnectionId.remove(oldId)
                
                Log.d(TAG, "[HostLifecycle] Updated participant ID: $oldId -> $newId (connectionId=$connectionId)")
            }
        }
    }

    private fun cleanupParticipantConnectionById(connectionId: String, reason: String) {
        var shouldNotifyParticipantLeft = false
        var disconnectedParticipantId: String? = null
        
        synchronized(participantConnectionsLock) {
            val conn = participantConnections[connectionId]
            if (conn == null) {
                Log.d(TAG, "[HostLifecycle] Cleanup: connection $connectionId not found (already cleaned up)")
                return
            }
            
            // CRITICAL: Verify this connection is still the active one for its participantId
            val activeConnectionId = participantIdToConnectionId[conn.participantId]
            if (activeConnectionId != connectionId) {
                Log.d(TAG, "[HostLifecycle] Cleanup: connection $connectionId (participant ${conn.participantId}) is stale, active is $activeConnectionId. Skipping removal of active connection.")
                // This is a stale connection - just close its resources but don't remove the active mapping
                conn.readerJob?.cancel()
                conn.writerJob?.cancel()
                conn.heartbeatJob?.cancel()
                try { conn.writerChannel.close() } catch (e: Exception) {}
                try { conn.socket.close() } catch (e: Exception) {}
                // Remove the stale connection from the map
                participantConnections.remove(connectionId)
                return
            }
            
            // This IS the active connection - proceed with full cleanup
            Log.d(TAG, "[HostLifecycle] Cleaning up active connection $connectionId (participant ${conn.participantId}): $reason")
            conn.readerJob?.cancel()
            conn.writerJob?.cancel()
            conn.heartbeatJob?.cancel()
            try { conn.writerChannel.close() } catch (e: Exception) {}
            try { conn.socket.close() } catch (e: Exception) {}
            
            // Remove from both maps
            participantConnections.remove(connectionId)
            participantIdToConnectionId.remove(conn.participantId)
            
            // Update transport engine with remaining participants
            transportEngine?.updateParticipantSenders(getParticipantSenders())
            
            // Mark for participant-left notification
            shouldNotifyParticipantLeft = true
            disconnectedParticipantId = conn.participantId
        }
        
        // Notify Dart layer if this was a joined participant (not a pending connection)
        if (shouldNotifyParticipantLeft && disconnectedParticipantId != null && !disconnectedParticipantId.startsWith("pending-")) {
            if (isHosting) {
                val internalMsg = StringBuilder()
                internalMsg.append("{")
                internalMsg.append("\"protocolVersion\":1,")
                internalMsg.append("\"messageId\":\"${java.util.UUID.randomUUID()}\",")
                internalMsg.append("\"messageType\":\"INTERNAL_PARTICIPANT_LEFT\",")
                internalMsg.append("\"senderId\":\"${getFallbackDeviceId()}\",")
                internalMsg.append("\"generation\":0,")
                internalMsg.append("\"timestamp\":${System.currentTimeMillis()},")
                internalMsg.append("\"payload\":{")
                internalMsg.append("\"participantId\":\"$disconnectedParticipantId\"")
                internalMsg.append("}}")
                scope.launch { notifyMessage(internalMsg.toString()) }
            }
        }
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
        return sendJsonToConnection(message)
    }

    override fun sendChatMessage(text: String): Boolean {
        // Dart constructs the full ProtocolMessage.chat JSON and passes it to sendChatMessage
        Log.d(TAG, "[WriterDebug] sendChatMessage: text length=${text.length}")
        return sendJsonToConnection(text)
    }

    override fun sendProtocolMessage(message: String): Boolean {
        Log.d(TAG, "[WriterDebug] sendProtocolMessage: messageType preview = ${message.take(minOf(200, message.length))}")
        return sendJsonToConnection(message)
    }

    /** Send JSON string to the appropriate connection path (host fan-out or participant single connection). */
    private fun sendJsonToConnection(jsonString: String): Boolean {
        val payload = jsonString.toByteArray(StandardCharsets.UTF_8)
        return sendFrameToConnection(payload)
    }

    /** Send raw payload bytes to the appropriate connection path. */
    private fun sendFrameToConnection(payload: ByteArray): Boolean {
        val frame = buildFrame(payload)
        if (isHosting) {
            return fanOutFramed(frame)
        } else {
            return sendFrameToParticipant(frame)
        }
    }

    /** Build a framed payload (length prefix + payload). */
    private fun buildFrame(payload: ByteArray): ByteArray {
        val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
        frame[0] = (payload.size shr 24).toByte()
        frame[1] = (payload.size shr 16).toByte()
        frame[2] = (payload.size shr 8).toByte()
        frame[3] = payload.size.toByte()
        System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
        return frame
    }

    /** Send a pre-built frame to the participant's single writer channel. */
    private fun sendFrameToParticipant(frame: ByteArray): Boolean {
        return try {
            val result = writerChannel.trySend(frame)
            if (result.isSuccess) {
                socketWritesSucceeded.incrementAndGet()
                socketBytesWritten.addAndGet(frame.size.toLong())
                lastSocketWriteTimestampNanos.set(SystemClock.elapsedRealtimeNanos())
                true
            } else {
                // Channel full - this is the primary packet loss source under load
                socketWritesFailed.incrementAndGet()
                Log.w(TAG, "Participant writer queue full, dropping frame (capacity=200)")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enqueue frame on participant side", e)
            socketWritesFailed.incrementAndGet()
            false
        }
    }

    private fun fanOutFramed(frame: ByteArray): Boolean {
        var allSucceeded = true
        synchronized(participantConnectionsLock) {
            for ((participantId, connectionId) in participantIdToConnectionId) {
                val conn = participantConnections[connectionId] ?: continue
                val success = try {
                    val result = conn.writerChannel.trySend(frame)
                    if (result.isSuccess) {
                        socketWritesSucceeded.incrementAndGet()
                        socketBytesWritten.addAndGet(frame.size.toLong())
                        lastSocketWriteTimestampNanos.set(SystemClock.elapsedRealtimeNanos())
                        true
                    } else {
                        // Channel full - this is the primary packet loss source under load
                        socketWritesFailed.incrementAndGet()
                        Log.w(TAG, "Writer queue full for participant $participantId, dropping frame (capacity=200)")
                        false
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to enqueue frame for participant $participantId", e)
                    socketWritesFailed.incrementAndGet()
                    false
                }
                if (!success) allSucceeded = false
                socketWritesAttempted.incrementAndGet()
            }
        }
        return allSucceeded
    }

    /** Get current per-participant send functions for audio transport fan-out. */
    private fun getParticipantSenders(): Map<String, (String) -> Boolean> {
        val senders = mutableMapOf<String, (String) -> Boolean>()
        synchronized(participantConnectionsLock) {
            for ((participantId, connectionId) in participantIdToConnectionId) {
                val conn = participantConnections[connectionId] ?: continue
                // Only include participants with valid participant IDs (not pending)
                if (!participantId.startsWith("pending-")) {
                    senders[participantId] = { json ->
                        try {
                            val payload = json.toByteArray(StandardCharsets.UTF_8)
                            val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                            frame[0] = (payload.size shr 24).toByte()
                            frame[1] = (payload.size shr 16).toByte()
                            frame[2] = (payload.size shr 8).toByte()
                            frame[3] = payload.size.toByte()
                            System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                            
                            val result = conn.writerChannel.trySend(frame)
                            if (result.isSuccess) {
                                socketWritesSucceeded.incrementAndGet()
                                socketBytesWritten.addAndGet(payload.size.toLong() + FRAME_LENGTH_BYTES)
                                lastSocketWriteTimestampNanos.set(SystemClock.elapsedRealtimeNanos())
                                true
                            } else {
                                socketWritesFailed.incrementAndGet()
                                Log.w(TAG, "Writer queue full for participant $participantId, dropping frame (capacity=200)")
                                false
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to enqueue frame for participant $participantId", e)
                            socketWritesFailed.incrementAndGet()
                            false
                        }
                    }
                }
            }
        }
        return senders
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
            // Network reconnected: resume pipeline watchdog for current generation
            if (pipelineState == "ACTIVE") {
                startPipelineWatchdog(pipelineGeneration)
            }
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

    private fun startHeartbeatForParticipant(participantId: String) {
        // Legacy single-participant heartbeat - kept for backward compatibility
        // when this device is a participant (not hosting)
        if (!isHosting && heartbeatJob == null) {
            startHeartbeat()
        }
    }

    /** Start per-participant heartbeat monitoring for host connections. */
    private fun startPerParticipantHeartbeat(participantId: String, socket: Socket): Job {
        return scope.launch {
            Log.d(TAG, "[Heartbeat] Starting per-participant heartbeat for $participantId with interval=${heartbeatIntervalMs}ms, timeout=${heartbeatTimeoutMs}ms")
            var lastPingSent = 0L
            while (socket.isConnected && !socket.isClosed) {
                val now = System.currentTimeMillis()
                // Look up connection by current mapping (handles reconnects)
                val connectionId = participantIdToConnectionId[participantId]
                val conn = connectionId?.let { participantConnections[it] }
                if (conn == null) {
                    Log.d(TAG, "[Heartbeat] Participant $participantId no longer in connections, stopping heartbeat")
                    return@launch
                }
                
                // Check timeout
                val timeSinceLastHeartbeat = now - conn.lastHeartbeatReceivedMs.get()
                if (conn.lastHeartbeatReceivedMs.get() > 0 && timeSinceLastHeartbeat > heartbeatTimeoutMs) {
                    Log.w(TAG, "[Heartbeat] Timeout for $participantId: no heartbeat for ${timeSinceLastHeartbeat}ms (threshold=${heartbeatTimeoutMs}ms)")
                    handleParticipantTimeout(participantId)
                    return@launch
                }

                // Send PING at intervals
                if (now - lastPingSent >= heartbeatIntervalMs) {
                    sendPingToParticipant(participantId)
                    lastPingSent = now
                }

                // Wait for next check interval
                try {
                    delay(heartbeatIntervalMs / 2) // Check twice per interval
                } catch (e: CancellationException) {
                    return@launch
                } catch (e: Exception) {
                    Log.e(TAG, "[Heartbeat] Delay interrupted for $participantId", e)
                    return@launch
                }
            }
            Log.d(TAG, "[Heartbeat] Per-participant heartbeat loop ended for $participantId (socket closed or disconnected)")
        }
    }

    /** Send PING to a specific participant. */
    private fun sendPingToParticipant(participantId: String) {
        val connectionId = participantIdToConnectionId[participantId] ?: return
        val conn = participantConnections[connectionId] ?: return
        val pingJson = JSONObject().apply {
            put("protocolVersion", 1)
            put("messageId", java.util.UUID.randomUUID().toString())
            put("messageType", "PING")
            put("senderId", getFallbackDeviceId())
            put("generation", 0)
            put("timestamp", System.currentTimeMillis())
        }.toString()
        Log.d(TAG, "[Heartbeat] Sent PING to $participantId")
        // Use the participant's writer channel directly
        val payload = pingJson.toByteArray(StandardCharsets.UTF_8)
        val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
        frame[0] = (payload.size shr 24).toByte()
        frame[1] = (payload.size shr 16).toByte()
        frame[2] = (payload.size shr 8).toByte()
        frame[3] = payload.size.toByte()
        System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
        conn.writerChannel.trySend(frame)
    }

/** Handle heartbeat timeout for a specific participant. */
    private fun handleParticipantTimeout(participantId: String) {
        Log.w(TAG, "[Heartbeat] Handling participant timeout for $participantId")
        // Find the current connectionId for this participant
        val connectionId = participantIdToConnectionId[participantId]
        if (connectionId != null) {
            cleanupParticipantConnectionById(connectionId, "heartbeat_timeout")
        } else {
            Log.d(TAG, "[Heartbeat] No active connection found for participant $participantId (already cleaned up)")
        }
    }

    private suspend fun handleHeartbeatTimeout() {
        Log.w(TAG, "[Heartbeat] Handling heartbeat timeout (legacy participant-side)")
        heartbeatJob?.cancel()
        readerJob?.cancel()
        readerJob = null
        // This is for participant-side only (when this device is a participant)
        if (!isHosting) {
            // Participant: pause pipeline watchdog during reconnection
            stopPipelineWatchdog()
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

    private fun isHelloMessage(message: String): Boolean {
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            return messageType == "HELLO"
        } catch (e: Exception) {
            return false
        }
    }

    private fun handleHelloMessage(message: String, tempParticipantId: String) {
        try {
            val json = JSONObject(message)
            val participantId = json.optString("senderId", "")
            if (participantId.isNotEmpty()) {
                Log.d(TAG, "[HostLifecycle] Received HELLO from participantId=$participantId, updating connection mapping from $tempParticipantId")
                updateParticipantId(tempParticipantId, participantId)
                // Start per-participant heartbeat for this connection
                startParticipantHeartbeat(participantId)
                // Update transport engine with new participant
                transportEngine?.updateParticipantSenders(getParticipantSenders())
            } else {
                Log.w(TAG, "[HostLifecycle] HELLO message missing senderId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[HostLifecycle] Failed to parse HELLO message", e)
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
                // Update per-participant heartbeat timestamp for host
                if (isHosting) {
                    val senderId = json.optString("senderId", "")
                    if (senderId.isNotEmpty()) {
                        val connectionId = participantIdToConnectionId[senderId]
                        connectionId?.let { participantConnections[it]?.lastHeartbeatReceivedMs?.set(System.currentTimeMillis()) }
                    }
                } else {
                    // Participant side: legacy single heartbeat
                    onHeartbeatReceived()
                }
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

    private fun isSyncMessage(message: String): Boolean {
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            return messageType == "TIME_SYNC_REQUEST" ||
                   messageType == "TIME_SYNC_RESPONSE"
        } catch (e: Exception) {
            return false
        }
    }

    private fun handleSyncMessage(message: String) {
        packetsParsed.incrementAndGet()
        lastPacketParsedTimestampNanos.set(SystemClock.elapsedRealtimeNanos())
        try {
            val json = JSONObject(message)
            val messageType = json.optString("messageType", "")
            val sessionId = json.optString("sessionId", "")
            val generation = json.optLong("generation", 0)

            when (messageType) {
                "TIME_SYNC_REQUEST" -> {
                    val payload = json.optJSONObject("payload")
                    if (payload != null) {
                        val t1 = payload.optLong("t1", 0)
                        if (t1 > 0) {
                            val t2 = SystemClock.elapsedRealtimeNanos()
                            val t3 = SystemClock.elapsedRealtimeNanos()
                            Log.i(TAG, "[Sync] Received TIME_SYNC_REQUEST: t1=$t1, gen=$generation")
                            sendTimeSyncResponse(sessionId, generation, t1, t2, t3)
                        }
                    }
                }
                "TIME_SYNC_RESPONSE" -> {
                    val payload = json.optJSONObject("payload")
                    if (payload != null) {
                        val t1 = payload.optLong("t1", 0)
                        val t2 = payload.optLong("t2", 0)
                        val t3 = payload.optLong("t3", 0)
                        if (t1 > 0 && t2 > 0 && t3 > 0) {
                            Log.i(TAG, "[Sync] Received TIME_SYNC_RESPONSE: t1=$t1 t2=$t2 t3=$t3, gen=$generation")
                            // Forward to Flutter sync repository (must run on main thread for @UiThread Pigeon API)
                            Log.d(TAG, "[Sync] pipelineFlutterApi=${pipelineFlutterApi != null}")
                            Log.d(TAG, "[Sync] About to forward TIME_SYNC_RESPONSE to Dart: gen=$generation session=$sessionId")
                            // Get senderId from the JSON payload (the participant who sent the response)
                            val senderId = json.optString("senderId", "")
                            scope.launch(Dispatchers.Main) {
                                Log.d(TAG, "[Sync] TIME_SYNC_RESPONSE coroutine started on ${Thread.currentThread().name}")
                                try {
                                    pipelineFlutterApi?.onTimeSyncResponse(
                                        TimeSyncResponse(
                                            t1 = t1,
                                            t2 = t2,
                                            t3 = t3,
                                            generation = generation,
                                            sessionId = sessionId,
                                            senderId = senderId,
                                        )
                                    )
                                    Log.d(TAG, "[Sync] Successfully forwarded TIME_SYNC_RESPONSE to Dart from $senderId")
                                } catch (e: Throwable) {
                                    Log.e(TAG, "[Sync] Failed to forward TIME_SYNC_RESPONSE to Dart", e)
                                }
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "[Sync] Failed to handle sync message", e)
            packetsParseFailed.incrementAndGet()
        }
    }

    private fun sendTimeSyncResponse(
        sessionId: String,
        generation: Long,
        t1: Long,
        t2: Long,
        t3: Long,
    ) {
        val participantId = currentParticipantId ?: getFallbackDeviceId()
        val response = JSONObject().apply {
            put("protocolVersion", 1)
            put("messageId", java.util.UUID.randomUUID().toString())
            put("messageType", "TIME_SYNC_RESPONSE")
            put("sessionId", sessionId)
            put("senderId", participantId)
            put("generation", generation)
            put("timestamp", System.currentTimeMillis())
            put("payload", JSONObject().apply {
                put("t1", t1)
                put("t2", t2)
                put("t3", t3)
            })
        }.toString()
        Log.d(TAG, "[Sync] Sent TIME_SYNC_RESPONSE: t1=$t1 t2=$t2 t3=$t3")
        buildAndEnqueueJson(response)
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
                        // Participant adopts stream generation into local pipelineGeneration
                        if (!isHosting && generation > pipelineGeneration) {
                            pipelineGeneration = generation
                            scope.launch { notifyPipelineState("STREAM_INFO", generation) }
                            Log.i(TAG, "[Pipeline] Participant adopted stream generation: $generation")
                        }
                        receiveEngine?.onStreamInfo(sessionId, generation, sampleRate, channelCount)
                        outputEngine?.onStreamInfo(generation, sampleRate, channelCount, startedAtNanos)
                    }
                }
                "AUDIO_STREAM_START" -> {
                    Log.i(TAG, "[AudioTransport] Received AUDIO_STREAM_START: gen=$generation")
                    // Participant adopts stream generation into local pipelineGeneration
                    if (!isHosting && generation > pipelineGeneration) {
                        pipelineGeneration = generation
                        scope.launch { notifyPipelineState("STREAM_START", generation) }
                        Log.i(TAG, "[Pipeline] Participant adopted stream generation: $generation")
                    }
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
                                    recordAudioActivity()
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
        val originalMessageId = pingJson.optString("messageId", "")
        val pongJson = JSONObject().apply {
            put("protocolVersion", 1)
            put("messageId", java.util.UUID.randomUUID().toString())
            put("messageType", "PONG")
            put("senderId", getFallbackDeviceId())
            put("generation", 0)
            put("timestamp", System.currentTimeMillis())
            put("payload", JSONObject().put("originalMessageId", originalMessageId))
        }.toString()
        Log.d(TAG, "[Heartbeat] Sent PONG")
        
        if (isHosting) {
            // Host: send PONG back to the specific participant who sent the PING
            val senderId = pingJson.optString("senderId", "")
            if (senderId.isNotEmpty()) {
                enqueueFrameToParticipant(senderId, pongJson.toByteArray(StandardCharsets.UTF_8))
            }
        } else {
            // Participant: use legacy single connection
            val socket = connectionSocket ?: return
            buildAndEnqueueJson(pongJson)
        }
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
        try { writerChannel.close() } catch (e: Exception) {}
        writerChannel = kotlinx.coroutines.channels.Channel<ByteArray>(capacity = 200)
        writerJob = scope.launch(Dispatchers.IO) { writerLoop(socket, writerChannel) }

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
                        } else if (isSyncMessage(message)) {
                            handleSyncMessage(message)
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
                // Network disconnected: pause pipeline watchdog (will restart on reconnect)
                stopPipelineWatchdog()
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

        // Clean up all participant connections
        synchronized(participantConnectionsLock) {
            for ((participantId, conn) in participantConnections) {
                Log.d(TAG, "[HostLifecycle] stopAll: cleaning up participant $participantId")
                conn.readerJob?.cancel()
                conn.writerJob?.cancel()
                try { conn.writerChannel.close() } catch (e: Exception) {}
                try { conn.socket.close() } catch (e: Exception) {}
            }
            participantConnections.clear()
        }

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

        // Stop discovery broadcast so the room code is no longer advertised
        discoveryService.stopBroadcast()

        // Stop pipeline (includes audio engines)
        scope.launch { stopPipeline() }

        Log.d(TAG, "[HostLifecycle] stopAll: completed")
    }

    // ---- Phase 10: Pipeline coordination ----

    /**
     * Start the complete capture-to-output pipeline with explicit ordering and rollback.
     * Order: Capture → Transport → (Receive/Output auto-start via network messages)
     * If any stage fails, previously started stages are stopped.
     */
    override suspend fun startPipeline(): Unit {
        Log.i(TAG, "[Pipeline] startPipeline called")
        if (pipelineState == "ACTIVE") {
            Log.w(TAG, "[Pipeline] Pipeline already active, ignoring startPipeline")
            return
        }

        val generation = ++pipelineGeneration
        pipelineState = "STARTING"
        notifyPipelineState("STARTING", generation)
        lastAudioActivityNanos.set(SystemClock.elapsedRealtimeNanos())

        try {
            // Stage 1: Start capture
            Log.i(TAG, "[Pipeline] Stage 1: Starting capture (gen=$generation)")
            pipelineState = "CAPTURE_STARTING"
            notifyPipelineState("CAPTURE_STARTING", generation)

            val captureResult = captureEngine?.start()
                ?: throw IllegalStateException("Capture engine not initialized")

            if (!captureResult.success) {
                val error = captureResult.error
                    ?: CaptureError(CaptureErrorClassifier.CAPTURE_START_FAILED, "Unknown capture failure")
                throw IllegalStateException("Capture failed: ${error.code} - ${error.message}")
            }

            val captureMetadata = captureResult.metadata
                ?: throw IllegalStateException("Capture succeeded but no metadata returned")

            // Stage 2: Start transport (host only)
            if (isHosting) {
                Log.i(TAG, "[Pipeline] Stage 2: Starting transport (gen=$generation)")
                pipelineState = "TRANSPORT_STARTING"
                notifyPipelineState("TRANSPORT_STARTING", generation)

                transportEngine?.startStreaming(captureMetadata)

                // Wait briefly for transport to be ready
                kotlinx.coroutines.delay(200)
            }

            // Stage 3: Start pipeline watchdog for silent stall detection
            startPipelineWatchdog(generation)

            pipelineState = "ACTIVE"
            notifyPipelineState("ACTIVE", generation)
            Log.i(TAG, "[Pipeline] Pipeline started successfully (gen=$generation)")

        } catch (e: Exception) {
            Log.e(TAG, "[Pipeline] startPipeline failed: ${e.message}", e)
            pipelineState = "FAILED"
            notifyPipelineError(PipelineError("PIPELINE_START_FAILED", e.message ?: "Unknown error", generation))
            notifyPipelineState("FAILED", generation)

            // Rollback: stop any stages that were started
            rollbackPipeline(generation)
            throw e
        }
    }

    /**
     * Stop the complete pipeline in safe order.
     * Order: Output → Receive → Transport → Capture
     * Idempotent: safe to call multiple times.
     */
    override suspend fun stopPipeline(): Unit {
        Log.i(TAG, "[Pipeline] stopPipeline called (state=$pipelineState, gen=$pipelineGeneration)")
        if (pipelineState == "IDLE" || pipelineState == "FAILED") {
            Log.d(TAG, "[Pipeline] Pipeline already stopped, idempotent stopPipeline")
            return
        }

        val generation = pipelineGeneration
        pipelineState = "STOPPING"
        notifyPipelineState("STOPPING", generation)

        // Stop watchdog first
        stopPipelineWatchdog()

        // Stage 1: Stop audible output
        Log.d(TAG, "[Pipeline] Stage 1: Stopping output")
        scope.launch { outputEngine?.onStreamStop(generation) }

        // Stage 2: Stop receiving/consuming stream data
        Log.d(TAG, "[Pipeline] Stage 2: Stopping receive")
        scope.launch { receiveEngine?.onStreamStop(generation) }

        // Stage 3: Stop transport/network audio production
        Log.d(TAG, "[Pipeline] Stage 3: Stopping transport")
        scope.launch { transportEngine?.stopStreaming() }

        // Stage 4: Stop capture
        Log.d(TAG, "[Pipeline] Stage 4: Stopping capture")
        scope.launch { captureEngine?.stop() }

        // Stage 5: Cancel lifecycle coroutines/jobs (handled by stopAll for broader cleanup)
        // But ensure pipeline-specific jobs are cancelled
        cancelPipelineJobs()

        pipelineState = "IDLE"
        pipelineGeneration = 0
        notifyPipelineState("IDLE", 0)
        Log.i(TAG, "[Pipeline] Pipeline stopped")
    }

    private fun rollbackPipeline(generation: Long) {
        Log.w(TAG, "[Pipeline] Rolling back pipeline (gen=$generation)")
        scope.launch { outputEngine?.onStreamStop(generation) }
        scope.launch { receiveEngine?.onStreamStop(generation) }
        scope.launch { transportEngine?.stopStreaming() }
        scope.launch { captureEngine?.stop() }
        cancelPipelineJobs()
    }

    private fun cancelPipelineJobs() {
        pipelineWatchdogJob?.cancel()
        pipelineWatchdogJob = null
    }

    private fun startPipelineWatchdog(generation: Long) {
        stopPipelineWatchdog()
        pipelineWatchdogJob = scope.launch {
            try {
                while (pipelineState == "ACTIVE" && pipelineGeneration == generation) {
                    kotlinx.coroutines.delay(2000)
                    val now = SystemClock.elapsedRealtimeNanos()
                    val lastActivityAgeMs = if (lastAudioActivityNanos.get() > 0) {
                        (now - lastAudioActivityNanos.get()) / 1_000_000
                    } else -1L

                    // Only check for stall if we've had audio activity before
                    if (lastActivityAgeMs > 0 && lastActivityAgeMs > PIPELINE_STALL_THRESHOLD_MS) {
                        // Verify we're not in the middle of intentional stop/start
                        if (pipelineState == "ACTIVE" && pipelineGeneration == generation) {
                            Log.w(TAG, "[Pipeline] Silent stall detected: no audio activity for ${lastActivityAgeMs}ms")
                            notifyPipelineError(PipelineError("SILENT_STALL_DETECTED", "No audio frame/packet activity for ${lastActivityAgeMs}ms", generation))
                            // Transition to failed and rollback
                            pipelineState = "FAILED"
                            notifyPipelineState("FAILED", generation)
                            rollbackPipeline(generation)
                            break
                        }
                    }
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                // Expected on stop
            } catch (e: Exception) {
                Log.e(TAG, "[Pipeline] Watchdog failed", e)
            }
        }
        Log.d(TAG, "[Pipeline] Watchdog started (threshold=${PIPELINE_STALL_THRESHOLD_MS}ms)")
    }

    private fun stopPipelineWatchdog() {
        pipelineWatchdogJob?.cancel()
        pipelineWatchdogJob = null
        Log.d(TAG, "[Pipeline] Watchdog stopped")
    }

    // Called from capture/transport/receive/output when audio frames/packets flow
    private fun recordAudioActivity() {
        lastAudioActivityNanos.set(SystemClock.elapsedRealtimeNanos())
    }

    override fun getPipelineGeneration(): Long = pipelineGeneration

    override fun getPipelineState(): String = pipelineState

    override fun getSyncState(): String = syncState

    override fun updateSyncState(state: String, generation: Long, offsetMs: Double, driftMsPerSecond: Double?) {
        syncState = state
        syncOffsetMs = offsetMs
        syncDriftMsPerSecond = driftMsPerSecond
        Log.i(TAG, "[Pipeline] Sync state updated: $state (gen=$generation) offsetMs=$offsetMs driftMsPerSecond=$driftMsPerSecond")
    }

    override fun scheduleFrame(
        framePosition: Long,
        targetNativeTimeNanos: Long,
        generation: Long
    ): ScheduleResult {
        return outputEngine?.scheduleFrame(framePosition, targetNativeTimeNanos, generation)
            ?: ScheduleResult(false, "OUTPUT_NOT_READY", "Output engine not initialized")
    }

    override fun getNextFrameInfo(): NextFrameInfo? {
        return receiveEngine?.getNextFrameInfo()
    }

    private suspend fun notifyPipelineState(state: String, generation: Long) {
        withContext(Dispatchers.Main) {
            try {
                pipelineFlutterApi?.onPipelineStateChanged(state, generation)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify pipeline state", e)
            }
        }
    }

    private suspend fun notifyPipelineError(error: PipelineError) {
        withContext(Dispatchers.Main) {
            try {
                pipelineFlutterApi?.onPipelineError(error)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify pipeline error", e)
            }
        }
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
        stopAll()
        scope.coroutineContext[Job]?.cancel()
        discoveryService.dispose()
        super.onDestroy()
    }

    /** Periodic network diagnostics reporter for pipeline tracing (BUG #3). */
    private suspend fun networkDiagnosticsReporter() {
        try {
            while (true) {
                kotlinx.coroutines.delay(2000)
                val now = SystemClock.elapsedRealtimeNanos()
                
                // Check if any participant connections are still active
                var hasActiveConnections = false
                synchronized(participantConnectionsLock) {
                    for ((_, conn) in participantConnections) {
                        if (conn.socket.isConnected && !conn.socket.isClosed) {
                            hasActiveConnections = true
                            break
                        }
                    }
                }
                
                if (!hasActiveConnections) {
                    Log.d(TAG, "[DIAG] No active participant connections, stopping diagnostics reporter")
                    return
                }
                
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
                
                // Per-participant diagnostics
                synchronized(participantConnectionsLock) {
                    for ((participantId, conn) in participantConnections) {
                        if (conn.socket.isConnected && !conn.socket.isClosed) {
                            Log.d(TAG, "[DIAG] Participant $participantId: socket connected")
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Network diagnostics reporter failed", e)
        }
    }

    /** Per-participant writer loop: serializes all TCP frame writes for one participant. */
    private suspend fun writerLoop(socket: Socket, channel: kotlinx.coroutines.channels.Channel<ByteArray>) {
        val outputStream = socket.getOutputStream()
        try {
            for (frame in channel) {
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

                    channel.close()
                    break
                }
            }
        } catch (e: kotlinx.coroutines.channels.ClosedReceiveChannelException) {
            // Normal shutdown
        } catch (e: Exception) {
            Log.e(TAG, "Writer loop failed", e)
        }
    }

    /** Enqueue a frame to a specific participant's writer channel. Returns true if enqueued. */
    private fun enqueueFrameToParticipant(participantId: String, frame: ByteArray): Boolean {
        synchronized(participantConnectionsLock) {
            val conn = participantConnections[participantId] ?: return false
            val channel = conn.writerChannel
            socketWritesAttempted.incrementAndGet()

            return try {
                val result = channel.trySend(frame)
                if (result.isSuccess) {
                    true
                } else {
                    // Channel full - this is the primary packet loss source under load
                    socketWritesFailed.incrementAndGet()
                    Log.w(TAG, "Writer queue full for participant $participantId, dropping frame (capacity=200)")
                    false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enqueue frame for participant $participantId", e)
                socketWritesFailed.incrementAndGet()
                false
            }
        }
    }

    /** Helper to construct a framed payload and enqueue it to the appropriate connection. */
    private fun buildAndEnqueueFrame(payload: ByteArray): Boolean {
        return sendFrameToConnection(payload)
    }

    /** Helper to construct a framed JSON string and enqueue it to the appropriate connection. */
    private fun buildAndEnqueueJson(jsonString: String): Boolean {
        val payload = jsonString.toByteArray(StandardCharsets.UTF_8)
        return sendFrameToConnection(payload)
    }
}
