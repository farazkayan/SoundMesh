package com.soundmesh.soundmesh.discovery

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.SocketException
import java.net.UnknownHostException
import java.nio.charset.StandardCharsets
import java.util.Enumeration
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Android native implementation of UDP broadcast discovery for SoundMesh.
 * Handles both host-side room announcement broadcasting and participant-side scanning.
 */
class DiscoveryService(private val context: Context) {

    companion object {
        private const val TAG = "SoundMeshDiscovery"
        const val DISCOVERY_PORT = 54321
        const val BROADCAST_INTERVAL_SECONDS = 2
        const val SCAN_TIMEOUT_SECONDS = 15
        const val MAX_PAYLOAD_SIZE = 512
        const val PROTOCOL_VERSION = 1
    }

    private var broadcastExecutor: ScheduledExecutorService? = null
    private var broadcastSocket: DatagramSocket? = null
    private var scanSocket: DatagramSocket? = null
    private var scanExecutor: ScheduledExecutorService? = null
    
    private val isBroadcasting = AtomicBoolean(false)
    private val isScanning = AtomicBoolean(false)
    private val scanListener = AtomicReference<(RoomAnnouncement) -> Unit>()

    data class RoomAnnouncement(
        val code: String,
        val hostIp: String,
        val hostPort: Int,
        val protocolVersion: Int,
        val roomId: String,
        val hostName: String?
    )

    /**
     * Gets the local non-loopback IPv4 address for broadcasting.
     */
    fun getLocalIpAddress(): String? {
        try {
            val interfaces: Enumeration<NetworkInterface> = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                val addresses: Enumeration<InetAddress> = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                        Log.d(TAG, "🔍 Found non-loopback IPv4: ${address.hostAddress} on interface ${networkInterface.name}")
                        return address.hostAddress
                    } else {
                        Log.d(TAG, "⏭️ Skipping address: ${address.hostAddress} (loopback=${address.isLoopbackAddress}, isIpv4=${address is java.net.Inet4Address}) on ${networkInterface.name}")
                    }
                }
            }
        } catch (e: SocketException) {
            Log.e(TAG, "Error getting local IP address", e)
        }
        Log.w(TAG, "❌ No suitable local IP found")
        return null
    }

    /**
     * Checks if local network permission is granted (Android 13+).
     */
    fun hasLocalNetworkPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ requires NEARBY_WIFI_DEVICES permission
            return context.checkSelfPermission("android.permission.NEARBY_WIFI_DEVICES") == android.content.pm.PackageManager.PERMISSION_GRANTED
        }
        return true // Pre-Android 13 doesn't require special permission
    }

    /**
     * Requests local network permission (Android 13+).
     * Note: Actual permission request must be done from an Activity.
     */
    fun requestLocalNetworkPermission(): Boolean {
        // This is a stub - actual permission request needs Activity context
        return hasLocalNetworkPermission()
    }

    /**
     * Starts broadcasting room announcements on the local network.
     */
    fun startBroadcast(
        code: String,
        hostIp: String,
        hostPort: Int,
        roomId: String,
        hostName: String?,
        intervalSeconds: Int = BROADCAST_INTERVAL_SECONDS
    ): Boolean {
        if (isBroadcasting.get()) {
            Log.w(TAG, "⚠️ Already broadcasting, stopping previous")
            stopBroadcast()
        }

        val ipAddress = getLocalIpAddress() ?: return false
        
        try {
            broadcastSocket = DatagramSocket(DISCOVERY_PORT).apply {
                setBroadcast(true)
                setReuseAddress(true)
                Log.d(TAG, "📡 Broadcast socket created on port $DISCOVERY_PORT, broadcast=true, reuseAddr=true")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to create broadcast socket", e)
            return false
        }

        val announcement = buildAnnouncementJson(code, hostIp, hostPort, roomId, hostName)
        val broadcastAddress = getBroadcastAddress(ipAddress) ?: return false

        broadcastExecutor = Executors.newSingleThreadScheduledExecutor()
        isBroadcasting.set(true)

        broadcastExecutor!!.scheduleAtFixedRate({
            if (!isBroadcasting.get()) return@scheduleAtFixedRate
            
            try {
                val data = announcement.toByteArray(StandardCharsets.UTF_8)
                val packet = DatagramPacket(data, data.size, broadcastAddress, DISCOVERY_PORT)
                broadcastSocket?.send(packet)
                Log.d(TAG, "📤 BROADCAST #${System.currentTimeMillis()} → $broadcastAddress:$DISCOVERY_PORT (${data.size} bytes): $announcement")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error sending broadcast", e)
            }
        }, 0, intervalSeconds.toLong(), TimeUnit.SECONDS)

        Log.i(TAG, "✅ Started broadcasting room code: $code on $ipAddress:$DISCOVERY_PORT → $broadcastAddress:$DISCOVERY_PORT every ${intervalSeconds}s")
        return true
    }

    /**
     * Stops broadcasting room announcements.
     */
    fun stopBroadcast() {
        isBroadcasting.set(false)
        broadcastExecutor?.shutdownNow()
        broadcastExecutor = null
        broadcastSocket?.close()
        broadcastSocket = null
        Log.i(TAG, "Stopped broadcasting")
    }

    /**
     * Starts scanning for room announcements matching the given code.
     */
    fun startScan(
        targetCode: String,
        timeoutSeconds: Int = SCAN_TIMEOUT_SECONDS,
        onAnnouncement: (RoomAnnouncement) -> Unit,
        onTimeout: () -> Unit
    ): Boolean {
        Log.i(TAG, "[JOIN_TRACE] DiscoveryService: startScan ENTERED for targetCode: $targetCode (timeout: ${timeoutSeconds}s)")
        if (isScanning.get()) {
            Log.w(TAG, "[JOIN_TRACE] DiscoveryService: Already scanning, stopping previous scan")
            stopScan()
        }

        try {
            scanSocket = DatagramSocket(DISCOVERY_PORT).apply {
                setReuseAddress(true)
                setSoTimeout(1000) // 1 second timeout for receive
                Log.d(TAG, "[JOIN_TRACE] DiscoveryService: Scan socket created on port $DISCOVERY_PORT, reuseAddr=true, soTimeout=1000ms")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[JOIN_TRACE] DiscoveryService: Failed to create scan socket", e)
            return false
        }

        scanListener.set(onAnnouncement)
        isScanning.set(true)

        scanExecutor = Executors.newSingleThreadScheduledExecutor()
        
        // Timeout task
        scanExecutor!!.schedule({
            if (isScanning.get()) {
                Log.w(TAG, "[JOIN_TRACE] DiscoveryService: Scan timeout after ${timeoutSeconds}s for code: $targetCode")
                stopScan()
                onTimeout()
            }
        }, timeoutSeconds.toLong(), TimeUnit.SECONDS)

        // Receive loop
        scanExecutor!!.execute {
            val buffer = ByteArray(MAX_PAYLOAD_SIZE)
            val packet = DatagramPacket(buffer, buffer.size)
            var packetCount = 0
            
            Log.i(TAG, "[JOIN_TRACE] DiscoveryService: Started scanning for room code: $targetCode (timeout: ${timeoutSeconds}s)")
            
            while (isScanning.get()) {
                try {
                    scanSocket?.receive(packet)
                    packetCount++
                    val json = String(packet.data, 0, packet.length, StandardCharsets.UTF_8)
                    val senderIp = packet.address.hostAddress
                    val senderPort = packet.port
                    
                    Log.d(TAG, "[JOIN_TRACE] DiscoveryService: UDP PACKET #$packetCount from $senderIp:$senderPort (${packet.length} bytes): $json")
                    
                    parseAnnouncement(json)?.let { announcement ->
                        Log.d(TAG, "[JOIN_TRACE] DiscoveryService: PARSED announcement: code=${announcement.code} hostIp=${announcement.hostIp} hostPort=${announcement.hostPort} roomId=${announcement.roomId} hostName=${announcement.hostName}")
                        if (announcement.code == targetCode) {
                            Log.i(TAG, "[JOIN_TRACE] DiscoveryService: MATCH FOUND! code=$targetCode from $senderIp:$senderPort")
                            scanListener.get()?.invoke(announcement)
                            stopScan()
                            break
                        } else {
                            Log.d(TAG, "[JOIN_TRACE] DiscoveryService: Ignored non-matching code: ${announcement.code} (want $targetCode)")
                        }
                    } ?: run {
                        Log.w(TAG, "[JOIN_TRACE] DiscoveryService: Failed to parse announcement from $senderIp:$senderPort")
                    }
                } catch (e: java.net.SocketTimeoutException) {
                    // Timeout is expected, continue scanning
                    if (packetCount % 10 == 0) {
                        Log.d(TAG, "[JOIN_TRACE] DiscoveryService: Still scanning... (${packetCount} packets received so far)")
                    }
                } catch (e: Exception) {
                    if (isScanning.get()) {
                        Log.e(TAG, "[JOIN_TRACE] DiscoveryService: Error receiving broadcast", e)
                    }
                }
            }
            Log.i(TAG, "[JOIN_TRACE] DiscoveryService: Scan loop ended. Total packets received: $packetCount")
        }

        Log.i(TAG, "[JOIN_TRACE] DiscoveryService: Started scanning for room code: $targetCode (timeout: ${timeoutSeconds}s)")
        return true
    }

    /**
     * Stops scanning for room announcements.
     */
    fun stopScan() {
        Log.i(TAG, "[JOIN_TRACE] DiscoveryService: stopScan called")
        isScanning.set(false)
        scanExecutor?.shutdownNow()
        scanExecutor = null
        scanSocket?.close()
        scanSocket = null
        scanListener.set(null)
        Log.i(TAG, "Stopped scanning")
    }

    /**
     * Builds the JSON announcement payload.
     */
    private fun buildAnnouncementJson(
        code: String,
        hostIp: String,
        hostPort: Int,
        roomId: String,
        hostName: String?
    ): String {
        val map = mutableMapOf<String, Any>(
            "type" to "room_announcement",
            "version" to PROTOCOL_VERSION,
            "code" to code,
            "host_ip" to hostIp,
            "host_port" to hostPort,
            "room_id" to roomId
        )
        hostName?.let { map["host_name"] = it }
        // Use standard JSON encoding to avoid kotlinx.serialization dependency
        val json = StringBuilder()
        json.append("{")
        var first = true
        map.forEach { (key, value) ->
            if (!first) json.append(",")
            first = false
            json.append("\"").append(key).append("\":")
            when (value) {
                is String -> json.append("\"").append(value).append("\"")
                is Int -> json.append(value)
                else -> json.append("\"").append(value.toString()).append("\"")
            }
        }
        json.append("}")
        return json.toString()
    }

    /**
     * Calculates broadcast address from local IP.
     */
    private fun getBroadcastAddress(localIp: String): InetAddress? {
        return try {
            val parts = localIp.split(".")
            if (parts.size == 4) {
                val broadcastIp = "${parts[0]}.${parts[1]}.${parts[2]}.255"
                val addr = InetAddress.getByName(broadcastIp)
                Log.d(TAG, "📍 Local IP: $localIp → Calculated broadcast: $broadcastIp")
                addr
            } else {
                val addr = InetAddress.getByName("255.255.255.255")
                Log.w(TAG, "⚠️ Non-standard IP format: $localIp, using 255.255.255.255")
                addr
            }
        } catch (e: UnknownHostException) {
            Log.e(TAG, "❌ Invalid broadcast address for $localIp", e)
            null
        }
    }

    /**
     * Parses a room announcement from JSON.
     */
    private fun parseAnnouncement(json: String): RoomAnnouncement? {
        return try {
            Log.d(TAG, "🔍 Parsing JSON: $json")
            // Simple JSON parsing without kotlinx.serialization
            val map = parseJsonMap(json)
            
            if (map["type"] != "room_announcement") {
                Log.w(TAG, "⚠️ Wrong message type: ${map["type"]} (expected room_announcement)")
                return null
            }
            if (map["version"] != PROTOCOL_VERSION) {
                Log.w(TAG, "⚠️ Wrong protocol version: ${map["version"]} (expected $PROTOCOL_VERSION)")
                return null
            }
            
            val code = map["code"] as? String ?: return null
            val hostIp = map["host_ip"] as? String ?: return null
            val hostPort = map["host_port"] as? Int ?: return null
            val roomId = map["room_id"] as? String ?: return null
            val hostName = map["host_name"] as? String
            
            if (!code.matches(Regex("^\\d{6}$"))) {
                Log.w(TAG, "⚠️ Invalid code format: $code")
                return null
            }
            
            Log.d(TAG, "✅ Valid announcement parsed: code=$code hostIp=$hostIp hostPort=$hostPort roomId=$roomId")
            RoomAnnouncement(code, hostIp, hostPort, PROTOCOL_VERSION, roomId, hostName)
        } catch (e: Exception) {
            Log.w(TAG, "❌ Failed to parse announcement: $json", e)
            null
        }
    }

    /**
     * Simple JSON parser for the discovery payload.
     */
    private fun parseJsonMap(json: String): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        val content = json.trim()
        if (!content.startsWith("{") || !content.endsWith("}")) return result
        val inner = content.substring(1, content.length - 1)
        val pairs = splitJsonPairs(inner)
        for (pair in pairs) {
            val colonIndex = pair.indexOf(':')
            if (colonIndex > 0) {
                val key = pair.substring(0, colonIndex).trim().trim('"')
                val value = pair.substring(colonIndex + 1).trim()
                result[key] = parseJsonValue(value)
            }
        }
        return result
    }

    private fun splitJsonPairs(str: String): List<String> {
        val result = mutableListOf<String>()
        val sb = StringBuilder()
        var inString = false
        var escaped = false
        for (c in str) {
            when {
                c == '"' && !escaped -> inString = !inString
                c == ',' && !inString -> {
                    result.add(sb.toString())
                    sb.clear()
                    continue
                }
            }
            if (c == '\\' && !escaped) {
                escaped = true
            } else {
                escaped = false
            }
            sb.append(c)
        }
        if (sb.isNotEmpty()) result.add(sb.toString())
        return result
    }

    private fun parseJsonValue(value: String): Any {
        val trimmed = value.trim()
        if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
            return trimmed.substring(1, trimmed.length - 1)
        }
        return try {
            trimmed.toInt()
        } catch (e: NumberFormatException) {
            try {
                trimmed.toLong()
            } catch (e: NumberFormatException) {
                if (trimmed == "true" || trimmed == "false") {
                    trimmed.toBoolean()
                } else {
                    trimmed
                }
            }
        }
    }

    /**
     * Cleans up all resources.
     */
    fun dispose() {
        stopBroadcast()
        stopScan()
    }
}