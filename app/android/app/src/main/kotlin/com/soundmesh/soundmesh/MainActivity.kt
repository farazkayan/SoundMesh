package com.soundmesh.soundmesh

import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import com.soundmesh.soundmesh.capture.AudioCaptureEngine
import com.soundmesh.soundmesh.capture.CaptureErrorClassifier
import com.soundmesh.soundmesh.capture.CaptureSessionState
import com.soundmesh.soundmesh.capture.CaptureStateMachine
import com.soundmesh.soundmesh.capture.MediaProjectionHelper
import com.soundmesh.soundmesh.capture.CaptureDiagnostics
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

class MainActivity : FlutterActivity(), DevicePlatform, TimingPlatform, NetworkHostPlatform,
    AudioCapturePlatform {
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

    private var flutterApi: NetworkFlutterApi? = null

    // ---- Phase 5: external audio capture (feasibility spike) ----

    private val captureStateMachine = CaptureStateMachine()
    private var mediaProjectionHelper: MediaProjectionHelper? = null
    private var captureEngine: AudioCaptureEngine? = null
    private var captureFlutterApi: AudioCaptureFlutterApi? = null

    companion object {
        private const val FRAME_LENGTH_BYTES = 4
        private const val CONNECT_TIMEOUT_MS = 10_000
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DevicePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        TimingPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        NetworkHostPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        flutterApi = NetworkFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
        AudioCapturePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        captureFlutterApi = AudioCaptureFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
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
            diagnostics = CaptureDiagnostics(scope),
            notifyState = { state, metadata -> notifyCaptureState(state, metadata) },
            notifyError = { code, message -> notifyCaptureError(code, message) },
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
                true
            }
        }
        if (!shouldStartReading) {
            Log.d(TAG, "[HostLifecycle] acceptConnection: closing accepted socket due to superseded hosting")
            socket.close()
            return
        }

        Log.d(TAG, "[HostLifecycle] acceptConnection: about to notifyState(connected) for accepted connection, gen=$generation")
        notifyState("connected")
        startReading(socket)
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
                notifyState("connected")
                startReading(socket)
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
        val socket = connectionSocket ?: return false
        scope.launch {
            // The coroutine body must catch its own exceptions: an uncaught
            // IOException (e.g. write to a closed socket) would crash the app.
            try {
                withContext(Dispatchers.IO) {
                    val payload = message.toByteArray(Charsets.UTF_8)
                    val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                    frame[0] = (payload.size shr 24).toByte()
                    frame[1] = (payload.size shr 16).toByte()
                    frame[2] = (payload.size shr 8).toByte()
                    frame[3] = payload.size.toByte()
                    System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                    
                    Log.d(TAG, "[WriterDebug] sendMessage: socket=$socket, socket.isConnected=${socket.isConnected}, socket.isClosed=${socket.isClosed}")
                    Log.d(TAG, "[WriterDebug] sendMessage: payloadSize=${payload.size}, frameSize=${frame.size}")
                    Log.d(TAG, "[WriterDebug] sendMessage: frame header bytes = ${frame[0].toInt() and 0xFF}, ${frame[1].toInt() and 0xFF}, ${frame[2].toInt() and 0xFF}, ${frame[3].toInt() and 0xFF}")
                    Log.d(TAG, "[WriterDebug] sendMessage: payload preview = ${message.take(minOf(200, message.length))}")
                    
                    val outputStream = socket.getOutputStream()
                    Log.d(TAG, "[WriterDebug] sendMessage: got outputStream=$outputStream")
                    Log.d(TAG, "[WriterDebug] sendMessage: BEFORE write")
                    outputStream.write(frame)
                    Log.d(TAG, "[WriterDebug] sendMessage: AFTER write, BEFORE flush")
                    outputStream.flush()
                    Log.d(TAG, "[WriterDebug] sendMessage: AFTER flush")
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "[WriterDebug] sendMessage: Exception: ${e.javaClass.simpleName}: ${e.message}", e)
            }
        }
        return true
    }

    override fun sendChatMessage(text: String): Boolean {
        val socket = connectionSocket ?: return false
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    // Dart constructs the full ProtocolMessage.chat JSON and passes it to sendChatMessage
                    val payload = text.toByteArray(Charsets.UTF_8)
                    val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                    frame[0] = (payload.size shr 24).toByte()
                    frame[1] = (payload.size shr 16).toByte()
                    frame[2] = (payload.size shr 8).toByte()
                    frame[3] = payload.size.toByte()
                    System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                    
                    Log.d(TAG, "[WriterDebug] sendChatMessage: text length=${text.length}")
                    val outputStream = socket.getOutputStream()
                    outputStream.write(frame)
                    outputStream.flush()
                }
            } catch (e: Exception) {
                Log.e(TAG, "sendChatMessage failed", e)
            }
        }
        return true
    }

    override fun sendProtocolMessage(message: String): Boolean {
        val socket = connectionSocket ?: return false
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val payload = message.toByteArray(Charsets.UTF_8)
                    val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                    frame[0] = (payload.size shr 24).toByte()
                    frame[1] = (payload.size shr 16).toByte()
                    frame[2] = (payload.size shr 8).toByte()
                    frame[3] = payload.size.toByte()
                    System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                    
                    Log.d(TAG, "[WriterDebug] sendProtocolMessage: messageType preview = ${message.take(minOf(200, message.length))}")
                    val outputStream = socket.getOutputStream()
                    outputStream.write(frame)
                    outputStream.flush()
                }
            } catch (e: Exception) {
                Log.e(TAG, "sendProtocolMessage failed", e)
            }
        }
        return true
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

    override fun setHeartbeatConfig(intervalMs: Long, timeoutMs: Long) {
        Log.d(TAG, "[Heartbeat] Configuring heartbeat: intervalMs=$intervalMs, timeoutMs=$timeoutMs")
        heartbeatIntervalMs = intervalMs
        heartbeatTimeoutMs = timeoutMs
        // Restart heartbeat if already running
        if (connectionSocket != null && connectionSocket!!.isConnected && !connectionSocket!!.isClosed) {
            startHeartbeat()
        }
    }

    override fun reconnectToHost(ipAddress: String, port: Long): Boolean {
        Log.d(TAG, "[Reconnection] reconnectToHost called: $ipAddress:$port")
        if (isHosting) {
            Log.w(TAG, "[Reconnection] Cannot reconnect while hosting")
            return false
        }
        lastKnownHostIp = ipAddress
        lastKnownHostPort = port.toInt()
        isReconnecting = true
        reconnectAttempts = 0
        scope.launch {
            attemptReconnect()
        }
        return true
    }

    private fun attemptReconnect() {
        val ip = lastKnownHostIp ?: return
        val port = lastKnownHostPort
        while (isReconnecting && reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++
            Log.d(TAG, "[Reconnection] Attempt $reconnectAttempts/$maxReconnectAttempts to $ip:$port")
            notifyState("reconnecting")
            val socket = Socket()
            try {
                socket.connect(InetSocketAddress(ip, port), CONNECT_TIMEOUT_MS)
            } catch (e: Exception) {
                Log.w(TAG, "[Reconnection] Attempt $reconnectAttempts failed: ${e.javaClass.simpleName}: ${e.message}")
                runCatching { socket.close() }
                if (!isReconnecting) return
                // Wait before retry with exponential backoff (capped)
                val delayMs = minOf(1000L * (1 shl (reconnectAttempts - 1)), 10000L)
                try {
                    Thread.sleep(delayMs)
                } catch (ie: InterruptedException) {
                    return
                }
                continue
            }

            synchronized(hostingLock) {
                if (!isReconnecting) {
                    runCatching { socket.close() }
                    return
                }
                clientSocket = socket
                connectionSocket = socket
            }

            Log.d(TAG, "[Reconnection] TCP reconnected to $ip:$port")
            notifyState("connected")
            startReading(socket)
            startHeartbeat()
            isReconnecting = false
            reconnectAttempts = 0
            return
        }

        if (isReconnecting) {
            Log.e(TAG, "[Reconnection] Max attempts ($maxReconnectAttempts) reached, giving up")
            isReconnecting = false
            notifyConnectionError("RECONNECTION_FAILED", "Failed to reconnect after $maxReconnectAttempts attempts")
            notifyState("failed")
        }
    }

    private fun startHeartbeat() {
        heartbeatJob?.cancel()
        lastHeartbeatReceivedMs = System.currentTimeMillis()
        heartbeatJob = scope.launch {
            Log.d(TAG, "[Heartbeat] Starting heartbeat with interval=${heartbeatIntervalMs}ms, timeout=${heartbeatTimeoutMs}ms")
            while (connectionSocket != null && connectionSocket!!.isConnected && !connectionSocket!!.isClosed) {
                val now = System.currentTimeMillis()
                val timeSinceLastHeartbeat = now - lastHeartbeatReceivedMs
                if (timeSinceLastHeartbeat > heartbeatTimeoutMs) {
                    Log.w(TAG, "[Heartbeat] Timeout: no heartbeat for ${timeSinceLastHeartbeat}ms (threshold=${heartbeatTimeoutMs}ms)")
                    handleHeartbeatTimeout()
                    return@launch
                }

                // Send PING
                sendPing()

                // Wait for next interval
                try {
                    Thread.sleep(heartbeatIntervalMs)
                } catch (e: InterruptedException) {
                    return@launch
                }
            }
            Log.d(TAG, "[Heartbeat] Heartbeat loop ended (socket closed or disconnected)")
        }
    }

    private fun sendPing() {
        val socket = connectionSocket ?: return
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val pingJson = """{"protocolVersion":1,"messageId":"${java.util.UUID.randomUUID()}","messageType":"PING","senderId":"${getDeviceId()}","generation":0,"timestamp":${System.currentTimeMillis()} }""".trimIndent()
                    val payload = pingJson.toByteArray(Charsets.UTF_8)
                    val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                    frame[0] = (payload.size shr 24).toByte()
                    frame[1] = (payload.size shr 16).toByte()
                    frame[2] = (payload.size shr 8).toByte()
                    frame[3] = payload.size.toByte()
                    System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                    val outputStream = socket.getOutputStream()
                    outputStream.write(frame)
                    outputStream.flush()
                    Log.d(TAG, "[Heartbeat] Sent PING")
                }
            } catch (e: Exception) {
                Log.e(TAG, "[Heartbeat] Failed to send PING: ${e.javaClass.simpleName}: ${e.message}")
            }
        }
    }

    private fun handleHeartbeatTimeout() {
        Log.w(TAG, "[Heartbeat] Handling heartbeat timeout")
        heartbeatJob?.cancel()
        if (isHosting) {
            // Host: notify about participant timeout
            notifyConnectionError("HEARTBEAT_TIMEOUT", "Participant heartbeat timeout")
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

    private fun getDeviceId(): String {
        // Use a stable device identifier - in practice this would be the participantId
        // For now, generate a simple identifier based on the device
        return "android-${Build.MODEL}-${Build.FINGERPRINT.hashCode()}"
    }

    private fun isHeartbeatMessage(message: String): Boolean {
        return message.contains("\"messageType\":\"PING\"") || message.contains("\"messageType\":\"PONG\"")
    }

    private fun handleHeartbeatMessage(message: String) {
        if (message.contains("\"messageType\":\"PING\"")) {
            Log.d(TAG, "[Heartbeat] Received PING, sending PONG")
            sendPong(message)
        } else if (message.contains("\"messageType\":\"PONG\"")) {
            Log.d(TAG, "[Heartbeat] Received PONG")
            onHeartbeatReceived()
        }
    }

    private fun sendPong(pingMessage: String) {
        val socket = connectionSocket ?: return
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    // Extract messageId from ping to echo back
                    var originalMessageId = ""
                    try {
                        val startIdx = pingMessage.indexOf("\"messageId\":\"") + 13
                        val endIdx = pingMessage.indexOf("\"", startIdx)
                        if (startIdx > 12 && endIdx > startIdx) {
                            originalMessageId = pingMessage.substring(startIdx, endIdx)
                        }
                    } catch (e: Exception) {
                        // Ignore parsing errors
                    }
                    val pongJson = """{"protocolVersion":1,"messageId":"${java.util.UUID.randomUUID()}","messageType":"PONG","senderId":"${getDeviceId()}","generation":0,"timestamp":${System.currentTimeMillis()},"payload":{"originalMessageId":"$originalMessageId"}}""".trimIndent()
                    val payload = pongJson.toByteArray(Charsets.UTF_8)
                    val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                    frame[0] = (payload.size shr 24).toByte()
                    frame[1] = (payload.size shr 16).toByte()
                    frame[2] = (payload.size shr 8).toByte()
                    frame[3] = payload.size.toByte()
                    System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                    val outputStream = socket.getOutputStream()
                    outputStream.write(frame)
                    outputStream.flush()
                    Log.d(TAG, "[Heartbeat] Sent PONG")
                }
            } catch (e: Exception) {
                Log.e(TAG, "[Heartbeat] Failed to send PONG: ${e.javaClass.simpleName}: ${e.message}")
            }
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

                    val messages = decoder.accept(buffer, 0, bytesRead)
                    for (message in messages) {
                        Log.d(TAG, "[ReaderDebug] Decoded message: ${message.take(minOf(200, message.length))}...")
                        // Handle heartbeat messages locally
                        if (isHeartbeatMessage(message)) {
                            handleHeartbeatMessage(message)
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
}
