package com.soundmesh.soundmesh

import android.os.Build
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.InputStream
import java.io.OutputStream
import java.net.Inet4Address
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.net.NetworkInterface

class MainActivity : FlutterActivity(), DevicePlatform, TimingPlatform, NetworkHostPlatform {
    private val TAG = "NetworkHandler"
    private val DEFAULT_PORT = 8765

    private val hostingLock = Any()
    @Volatile private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var connectionSocket: Socket? = null
    private var readerJob: Job? = null
    private var hostingJob: Job? = null
    private var hostingGeneration = 0L
    private var isHosting = false
    private val scope = CoroutineScope(Dispatchers.IO)

    private var flutterApi: NetworkFlutterApi? = null

    companion object {
        private const val FRAME_LENGTH_BYTES = 4
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DevicePlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        TimingPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        NetworkHostPlatform.setUp(flutterEngine.dartExecutor.binaryMessenger, this)
        flutterApi = NetworkFlutterApi(flutterEngine.dartExecutor.binaryMessenger)
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

    override fun startHosting(port: Long): Boolean {
        val generation: Long
        synchronized(hostingLock) {
            // A duplicate Create Room tap can arrive before Flutter rebuilds the
            // disabled button. Keep the active listener alive; explicit disconnect()
            // is the normal path that permits a new hosting attempt.
            if (isHosting) {
                Log.w(TAG, "Hosting already active; ignoring duplicate startHosting request")
                return true
            }

            generation = ++hostingGeneration
            isHosting = true
        }

        return try {
            val job = scope.launch {
                try {
                    notifyState("connecting")
                    val socket = ServerSocket(port.toInt())
                    synchronized(hostingLock) {
                        if (!isHosting || hostingGeneration != generation) {
                            socket.close()
                            return@launch
                        }
                        serverSocket = socket
                    }
                    notifyState("connected")
                    acceptConnection(generation)
                } catch (e: CancellationException) {
                    throw e
                } catch (e: SocketException) {
                    handleHostingFailure(generation, "Failed to start hosting", e)
                } catch (e: Exception) {
                    handleHostingFailure(generation, "Failed to start hosting", e)
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

    private suspend fun handleHostingFailure(
        generation: Long,
        message: String,
        e: Exception,
    ) {
        val socketToClose = synchronized(hostingLock) {
            if (isHosting && hostingGeneration == generation) {
                isHosting = false
                ++hostingGeneration
                val socket = serverSocket
                serverSocket = null
                socket
            } else {
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
        val socket = try {
            withContext(Dispatchers.IO) {
                listeningSocket?.accept()
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: SocketException) {
            if (isCurrentHosting(generation)) {
                handleHostingFailure(generation, "Error accepting connection", e)
            } else {
                Log.d(TAG, "Hosting listener closed during shutdown")
            }
            return
        } catch (e: Exception) {
            if (isCurrentHosting(generation)) {
                handleHostingFailure(generation, "Error accepting connection", e)
            } else {
                Log.d(TAG, "Ignoring accept failure from a superseded request")
            }
            return
        }

        if (socket == null) {
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
                false
            } else {
                connectionSocket = socket
                true
            }
        }
        if (!shouldStartReading) {
            socket.close()
            return
        }

        notifyState("connected")
        startReading(socket)
    }

    override fun connectToHost(ipAddress: String, port: Long): Boolean {
        return try {
            stopAll()
            scope.launch {
                notifyState("connecting")
                try {
                    clientSocket = Socket(ipAddress, port.toInt())
                    connectionSocket = clientSocket
                    notifyState("connected")
                    startReading(clientSocket!!)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to connect to host", e)
                    notifyState("failed")
                }
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
        return try {
            scope.launch {
                withContext(Dispatchers.IO) {
                    val payload = message.toByteArray(Charsets.UTF_8)
                    val frame = ByteArray(FRAME_LENGTH_BYTES + payload.size)
                    frame[0] = (payload.size shr 24).toByte()
                    frame[1] = (payload.size shr 16).toByte()
                    frame[2] = (payload.size shr 8).toByte()
                    frame[3] = payload.size.toByte()
                    System.arraycopy(payload, 0, frame, FRAME_LENGTH_BYTES, payload.size)
                    socket.getOutputStream().write(frame)
                    socket.getOutputStream().flush()
                }
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send message", e)
            false
        }
    }

    override fun disconnect() {
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

    private fun startReading(socket: Socket) {
        readerJob?.cancel()
        readerJob = scope.launch {
            val inputStream = socket.getInputStream()
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
                    val bytesRead = withContext(Dispatchers.IO) {
                        inputStream.read(buffer)
                    }
                    if (bytesRead == -1) break
                    if (bytesRead == 0) continue

                    val messages = decoder.accept(buffer, 0, bytesRead)
                    for (message in messages) {
                        notifyMessage(message)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading from socket", e)
            }
            notifyState("disconnected")
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
        val job: Job?
        synchronized(hostingLock) {
            job = hostingJob
            hostingJob = null
            ++hostingGeneration
            isHosting = false
        }
        job?.cancel()

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
        withContext(Dispatchers.Main) {
            try {
                flutterApi?.onConnectionStateChanged(state)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify state", e)
            }
        }
    }
}
