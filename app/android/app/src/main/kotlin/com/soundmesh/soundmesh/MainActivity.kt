package com.soundmesh.soundmesh

import android.os.Build
import android.os.SystemClock
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.InputStream
import java.io.OutputStream
import java.net.Inet4Address
import java.net.ServerSocket
import java.net.Socket
import java.net.NetworkInterface

class MainActivity : FlutterActivity(), DevicePlatform, TimingPlatform, NetworkHostPlatform {
    private val TAG = "NetworkHandler"
    private val DEFAULT_PORT = 8765

    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var connectionSocket: Socket? = null
    private var readerJob: Job? = null
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
        return try {
            stopAll()
            scope.launch {
                notifyState("connecting")
                serverSocket = ServerSocket(port.toInt())
                notifyState("connected")
                acceptConnection()
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start hosting", e)
            scope.launch { notifyState("failed") }
            false
        }
    }

    private suspend fun acceptConnection() {
        try {
            connectionSocket = withContext(Dispatchers.IO) {
                serverSocket?.accept()
            }
            if (connectionSocket != null) {
                notifyState("connected")
                startReading(connectionSocket!!)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error accepting connection", e)
            notifyState("failed")
        }
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
            var pendingLength: Int? = null
            var payloadBytesRead = 0
            var payloadBuffer: ByteArray? = null

            try {
                while (socket.isConnected && !socket.isClosed) {
                    val byte = withContext(Dispatchers.IO) {
                        inputStream.read()
                    }
                    if (byte == -1) break

                    if (pendingLength == null) {
                        if (payloadBytesRead < FRAME_LENGTH_BYTES) {
                            buffer[payloadBytesRead++] = byte.toByte()
                            if (payloadBytesRead == FRAME_LENGTH_BYTES) {
                                pendingLength = (buffer[0].toInt() and 0xFF shl 24) or
                                        (buffer[1].toInt() and 0xFF shl 16) or
                                        (buffer[2].toInt() and 0xFF shl 8) or
                                        (buffer[3].toInt() and 0xFF)
                                if (pendingLength!! <= 0 || pendingLength!! > 65536) {
                                    Log.w(TAG, "Invalid frame length: $pendingLength, resetting")
                                    pendingLength = null
                                    payloadBytesRead = 0
                                    payloadBuffer = null
                                } else {
                                    payloadBuffer = ByteArray(pendingLength!!)
                                }
                            }
                        }
                    } else {
                        payloadBuffer!![payloadBytesRead++] = byte.toByte()
                        if (payloadBytesRead == pendingLength) {
                            val message = String(payloadBuffer!!, Charsets.UTF_8)
                            notifyMessage(message)
                            pendingLength = null
                            payloadBytesRead = 0
                            payloadBuffer = null
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error reading from socket", e)
            }
            notifyState("disconnected")
        }
    }

    private fun stopAll() {
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
        try {
            serverSocket?.close()
        } catch (e: Exception) {}
        serverSocket = null
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
