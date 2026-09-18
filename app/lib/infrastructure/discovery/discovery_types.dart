// Discovery protocol types for SoundMesh local network room discovery.
// Uses UDP broadcast/multicast for 6-digit room code resolution.

import 'dart:convert';

/// Protocol version for discovery messages.
const int kDiscoveryProtocolVersion = 1;

/// UDP port for discovery broadcasts.
const int kDiscoveryPort = 54321;

/// Broadcast interval for host announcements (seconds).
const int kDiscoveryBroadcastIntervalSeconds = 2;

/// Discovery timeout for participant scanning (seconds).
const int kDiscoveryScanTimeoutSeconds = 15;

/// Maximum size of discovery payload in bytes.
const int kDiscoveryMaxPayloadSize = 512;

/// Discovery message types.
enum DiscoveryMessageType {
  /// Host announces room availability.
  roomAnnouncement('room_announcement'),
  
  /// Participant requests room info (future use).
  roomQuery('room_query'),
  
  /// Host responds to query (future use).
  roomResponse('room_response');

  const DiscoveryMessageType(this.value);
  final String value;
}

/// Room announcement payload broadcast by host.
class RoomAnnouncement {
  const RoomAnnouncement({
    required this.code,
    required this.hostIp,
    required this.hostPort,
    required this.protocolVersion,
    required this.roomId,
    this.hostName,
  });

  /// 6-digit numeric room code.
  final String code;

  /// Host's local IP address.
  final String hostIp;

  /// Host's TCP control port.
  final int hostPort;

  /// Discovery protocol version.
  final int protocolVersion;

  /// Unique room identifier.
  final String roomId;

  /// Optional human-readable host name.
  final String? hostName;

  /// Encodes to JSON string for UDP broadcast.
  String toJsonString() {
    final map = <String, dynamic>{
      'type': DiscoveryMessageType.roomAnnouncement.value,
      'version': protocolVersion,
      'code': code,
      'host_ip': hostIp,
      'host_port': hostPort,
      'room_id': roomId,
    };
    if (hostName != null) {
      map['host_name'] = hostName;
    }
    return jsonEncode(map);
  }

  /// Decodes from JSON string.
  static RoomAnnouncement? fromJsonString(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate message type
      if (map['type'] != DiscoveryMessageType.roomAnnouncement.value) {
        return null;
      }
      
      final version = map['version'] as int?;
      if (version != kDiscoveryProtocolVersion) {
        return null;
      }
      
      final code = map['code'] as String?;
      final hostIp = map['host_ip'] as String?;
      final hostPort = map['host_port'] as int?;
      final roomId = map['room_id'] as String?;
      
      if (code == null || hostIp == null || hostPort == null || roomId == null) {
        return null;
      }
      
      // Validate 6-digit code format
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        return null;
      }
      
      return RoomAnnouncement(
        code: code,
        hostIp: hostIp,
        hostPort: hostPort,
        protocolVersion: version ?? kDiscoveryProtocolVersion,
        roomId: roomId,
        hostName: map['host_name'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'RoomAnnouncement(code: $code, hostIp: $hostIp, hostPort: $hostPort, roomId: $roomId)';
}

/// Generates a random 6-digit numeric room code.
String generateRoomCode() {
  final random = DateTime.now().millisecondsSinceEpoch;
  // Use last 6 digits of timestamp + some randomness for better distribution
  final base = (random % 900000) + 100000; // Ensures 6 digits (100000-999999)
  return base.toString().padLeft(6, '0');
}

/// Validates a room code string.
bool isValidRoomCode(String code) {
  return RegExp(r'^\d{6}$').hasMatch(code);
}

/// Gets the local IP address for broadcast announcements.
/// Returns null if no suitable non-loopback IPv4 address is found.
Future<String?> getLocalIpAddress() async {
  // This will be implemented via platform channel to native Android
  // For now, return null to indicate platform implementation needed
  return null;
}

/// Result of starting host discovery broadcast.
class StartBroadcastResult {
  const StartBroadcastResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

/// Result of stopping host discovery broadcast.
class StopBroadcastResult {
  const StopBroadcastResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;
}

/// Stream event for discovered room announcements.
class DiscoveryEvent {
  const DiscoveryEvent({
    required this.announcement,
    this.isTimeout = false,
  });

  final RoomAnnouncement announcement;
  final bool isTimeout;
}