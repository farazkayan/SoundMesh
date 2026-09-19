// Discovery protocol types for SoundMesh local network room discovery.
// Uses UDP broadcast/multicast for 6-digit room code resolution.
//
// RoomAnnouncement is the live-transmission form of the transport-independent
// JoinPayload (see join_payload.dart). The wire contract is documented in
// DOCS/networking.md, "Join Payload Contract".

import 'dart:convert';
import 'dart:math';

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
///
/// This is the UDP-transmission form of the transport-independent JoinPayload.
/// The optional [expiresAt] field carries the join credential's expiration;
/// announcements without it (older senders) are treated as fresh because a
/// live UDP broadcast is inherently ephemeral (2s interval).
class RoomAnnouncement {
  const RoomAnnouncement({
    required this.code,
    required this.hostIp,
    required this.hostPort,
    required this.protocolVersion,
    required this.roomId,
    this.hostName,
    this.expiresAt,
  });

  /// 6-digit numeric room code. Doubles as the short-lived join credential.
  final String code;

  /// Host's local IP address.
  final String hostIp;

  /// Host's TCP control port.
  final int hostPort;

  /// Discovery protocol version.
  final int protocolVersion;

  /// Unique room identifier. MUST be the host's actual room identifier so a
  /// participant can verify it joined the advertised room.
  final String roomId;

  /// Optional human-readable host name.
  final String? hostName;

  /// When the join credential expires (wall-clock epoch). Null for senders
  /// that do not carry expiration.
  final DateTime? expiresAt;

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
    if (expiresAt != null) {
      map['expires_at'] = expiresAt!.millisecondsSinceEpoch;
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
      
      final expiresMillis = map['expires_at'] as int?;
      return RoomAnnouncement(
        code: code,
        hostIp: hostIp,
        hostPort: hostPort,
        protocolVersion: version ?? kDiscoveryProtocolVersion,
        roomId: roomId,
        hostName: map['host_name'] as String?,
        expiresAt: expiresMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(expiresMillis)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether the join credential carried by this announcement has expired,
  /// allowing a clock-skew allowance for wall-clock differences.
  bool isExpiredAt(DateTime? now, {Duration skew = const Duration(seconds: 60)}) {
    if (expiresAt == null) return false;
    final effectiveNow = now ?? DateTime.now();
    return effectiveNow.isAfter(expiresAt!.add(skew));
  }

  @override
  String toString() => 'RoomAnnouncement(code: $code, hostIp: $hostIp, hostPort: $hostPort, roomId: $roomId)';
}

/// Generates a random 6-digit numeric room code.
///
/// Cryptographically secure randomness is required: the previous
/// timestamp-derived implementation produced identical codes for calls in the
/// same millisecond and made codes predictable. The 6-digit format is kept —
/// it must remain difficult enough to guess within the practical threat model
/// (DOCS/interfaces/room-api.md §15).
String generateRoomCode() {
  final random = Random.secure();
  // 900000 codes in the 100000-999999 range, uniformly distributed.
  return (100000 + random.nextInt(900000)).toString();
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