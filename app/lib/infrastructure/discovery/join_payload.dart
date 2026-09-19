// Transport-independent join payload for SoundMesh room bootstrap.
//
// The same JoinPayload structure is carried by both bootstrap transports:
//   (a) the 6-digit code discovery flow (RoomAnnouncement over UDP broadcast), and
//   (b) the QR bootstrap flow (a scannable soundmesh://join URI, per DEC-013).
// Swapping or adding a transport must not change this data structure — only
// how it is transmitted and received.
//
// The join credential (code) is short-lived and single-purpose: it is scoped
// to one room session and expires, so no permanent credential is ever carried
// in a payload. See DOCS/networking.md, "Join Payload Contract".

import 'discovery_types.dart';

/// Protocol version this payload layer validates against.
/// Mirrors the discovery protocol version; both derive from the same
/// application protocol generation.
const int kJoinPayloadProtocolVersion = 1;

/// How long a join credential stays valid after it is issued.
///
/// Chosen as 10 minutes per the bootstrap task: long enough for a normal
/// create-then-join flow, short enough that a code seen or overheard cannot
/// be reused much later. The effective lifetime is also bounded by the host
/// session: broadcasting stops when the room closes.
const Duration kJoinCodeLifetime = Duration(minutes: 10);

/// Allowance for wall-clock differences between devices when validating
/// expiration. Phones generally sync via NTP to within a couple of seconds;
/// one minute is a generous safety margin against false CODE_EXPIRED results.
const Duration kJoinExpiryClockSkewAllowance = Duration(seconds: 60);

/// URI scheme/host used by the QR bootstrap payload (per DEC-013).
const String kJoinUriScheme = 'soundmesh';
const String kJoinUriHost = 'join';

/// Structured error codes for join payload generation, parsing, and
/// validation. These map onto the bootstrap error taxonomy in
/// DOCS/networking.md; raw exceptions must not leak into user-facing state.
enum JoinPayloadErrorCode {
  /// Malformed or corrupt payload: unparseable, missing required fields,
  /// or field values outside valid ranges.
  invalidPayload('INVALID_PAYLOAD'),

  /// The join credential's expiration time has passed (beyond the clock-skew
  /// allowance). Raised when parsing a static snapshot such as a QR payload.
  codeExpired('CODE_EXPIRED'),

  /// Payload was written for an incompatible protocol version.
  protocolVersionUnsupported('PROTOCOL_VERSION_UNSUPPORTED'),

  /// Discovery scan completed without finding the requested room code.
  /// Currently surfaced by the discovery scan timeout (null result).
  codeNotFound('CODE_NOT_FOUND'),

  /// Host-side rejection: the connected host does not recognize the room the
  /// payload refers to. Reserved for join rejection after a connect attempt;
  /// currently unreachable because a discovery-resolved connection always
  /// targets the advertising host directly.
  roomNotFound('ROOM_NOT_FOUND');

  const JoinPayloadErrorCode(this.wireValue);
  final String wireValue;
}

/// Structured exception for join payload failures. Carries a machine-readable
/// [code] from the bootstrap error taxonomy plus a human-readable message.
class JoinPayloadException implements Exception {
  const JoinPayloadException(this.code, this.message, {this.rawInput});

  final JoinPayloadErrorCode code;
  final String message;

  /// The raw input that failed to parse, when applicable. Must never contain
  /// credentials — join payloads only carry temporary bootstrap data.
  final String? rawInput;

  @override
  String toString() =>
      'JoinPayloadException(${code.wireValue}): $message${rawInput != null ? ' (input: $rawInput)' : ''}';
}

/// Transport-independent room join payload.
///
/// Fields are identical for both bootstrap transports:
///   - [roomId]: the room's actual identifier. Must be the same identifier the
///     host assigns to the room session, not a separate discovery-time value.
///   - [hostAddress]/[hostPort]: host TCP control endpoint.
///   - [protocolVersion]: application protocol version this payload targets.
///   - [code]: short-lived join credential (6-digit numeric in the MVP).
///   - [issuedAt]/[expiresAt]: credential lifetime. Optional on the wire so
///     older announcements without expiration remain parseable.
class JoinPayload {
  const JoinPayload({
    required this.roomId,
    required this.hostAddress,
    required this.hostPort,
    required this.protocolVersion,
    required this.code,
    this.issuedAt,
    this.expiresAt,
  });

  final String roomId;
  final String hostAddress;
  final int hostPort;
  final int protocolVersion;
  final String code;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  /// Issues a fresh, short-lived payload for a newly created room.
  factory JoinPayload.issue({
    required String roomId,
    required String hostAddress,
    required int hostPort,
    required String code,
    int protocolVersion = kJoinPayloadProtocolVersion,
    DateTime? now,
    Duration lifetime = kJoinCodeLifetime,
  }) {
    final issued = now ?? DateTime.now();
    return JoinPayload(
      roomId: roomId,
      hostAddress: hostAddress,
      hostPort: hostPort,
      protocolVersion: protocolVersion,
      code: code,
      issuedAt: issued,
      expiresAt: issued.add(lifetime),
    );
  }

  /// Builds a QR-scannable URI per DEC-013:
  ///
  /// ```
  /// soundmesh://join?room=<id>&host=<addr>&port=<port>&version=<v>
  ///     &token=<code>&expires=<epoch-millis>
  /// ```
  ///
  /// The join credential is transmitted in the `token` parameter per DEC-013.
  /// `expires` is omitted when the payload carries no expiration.
  String toJoinUri() {
    final params = <String, String>{
      'room': roomId,
      'host': hostAddress,
      'port': hostPort.toString(),
      'version': protocolVersion.toString(),
      'token': code,
    };
    if (expiresAt != null) {
      params['expires'] = expiresAt!.millisecondsSinceEpoch.toString();
    }
    return Uri(
      scheme: kJoinUriScheme,
      host: kJoinUriHost,
      queryParameters: params,
    ).toString();
  }

  /// Parses a QR-scannable join URI, enforcing version compatibility and
  /// expiration. Throws [JoinPayloadException] with a structured error code
  /// on any failure.
  static JoinPayload parseJoinUri(
    String raw, {
    DateTime? now,
    bool enforceExpiry = true,
    Duration clockSkewAllowance = kJoinExpiryClockSkewAllowance,
  }) {
    Uri uri;
    try {
      uri = Uri.parse(raw.trim());
    } on FormatException {
      throw const JoinPayloadException(
        JoinPayloadErrorCode.invalidPayload,
        'Join payload is not a valid URI',
      );
    }

    if (uri.scheme.toLowerCase() != kJoinUriScheme ||
        uri.host.toLowerCase() != kJoinUriHost) {
      throw JoinPayloadException(
        JoinPayloadErrorCode.invalidPayload,
        'Not a SoundMesh join URI (expected $kJoinUriScheme://$kJoinUriHost)',
        rawInput: raw,
      );
    }

    final params = uri.queryParameters;
    final roomId = params['room'];
    final hostAddress = params['host'];
    final portRaw = params['port'];
    final versionRaw = params['version'];
    // The credential is carried in `token` per DEC-013; `code` is accepted as
    // an alias so payloads built from the discovery naming stay parseable.
    final code = params['token'] ?? params['code'];
    final expiresRaw = params['expires'];

    if (roomId == null ||
        roomId.isEmpty ||
        hostAddress == null ||
        hostAddress.isEmpty ||
        portRaw == null ||
        versionRaw == null ||
        code == null ||
        code.isEmpty) {
      throw const JoinPayloadException(
        JoinPayloadErrorCode.invalidPayload,
        'Join URI is missing required fields (room, host, port, version, token)',
      );
    }

    final port = int.tryParse(portRaw);
    if (port == null || port < 1 || port > 65535) {
      throw const JoinPayloadException(
        JoinPayloadErrorCode.invalidPayload,
        'Join URI port is not a valid port number (1-65535)',
      );
    }

    final version = int.tryParse(versionRaw);
    if (version == null || version != kJoinPayloadProtocolVersion) {
      throw JoinPayloadException(
        JoinPayloadErrorCode.protocolVersionUnsupported,
        'Join URI targets unsupported protocol version '
        '$versionRaw (this device supports v$kJoinPayloadProtocolVersion)',
      );
    }

    DateTime? expiresAt;
    if (expiresRaw != null) {
      final expiresMillis = int.tryParse(expiresRaw);
      if (expiresMillis == null) {
        throw const JoinPayloadException(
          JoinPayloadErrorCode.invalidPayload,
          'Join URI expiration is not a valid epoch-millis value',
        );
      }
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresMillis);
      if (enforceExpiry && _isExpiredAt(expiresAt, now, clockSkewAllowance)) {
        throw const JoinPayloadException(
          JoinPayloadErrorCode.codeExpired,
          'Join credential has expired',
        );
      }
    }

    return JoinPayload(
      roomId: roomId,
      hostAddress: hostAddress,
      hostPort: port,
      protocolVersion: version,
      code: code,
      expiresAt: expiresAt,
    );
  }

  /// Builds a payload from a discovery announcement received over UDP.
  /// The announcement is the live-transmission form of the same payload.
  static JoinPayload fromAnnouncement(RoomAnnouncement announcement) {
    return JoinPayload(
      roomId: announcement.roomId,
      hostAddress: announcement.hostIp,
      hostPort: announcement.hostPort,
      protocolVersion: announcement.protocolVersion,
      code: announcement.code,
      expiresAt: announcement.expiresAt,
    );
  }

  /// Builds a discovery announcement for UDP broadcast from this payload.
  RoomAnnouncement toAnnouncement({String? hostName}) {
    return RoomAnnouncement(
      code: code,
      hostIp: hostAddress,
      hostPort: hostPort,
      protocolVersion: protocolVersion,
      roomId: roomId,
      hostName: hostName,
      expiresAt: expiresAt,
    );
  }

  /// Whether this payload's credential has expired at [now], allowing
  /// [clockSkewAllowance] for wall-clock differences between devices.
  bool isExpiredAt(
    DateTime? now, {
    Duration clockSkewAllowance = kJoinExpiryClockSkewAllowance,
  }) {
    if (expiresAt == null) return false;
    return _isExpiredAt(expiresAt!, now, clockSkewAllowance);
  }

  static bool _isExpiredAt(DateTime expiresAt, DateTime? now, Duration skew) {
    final effectiveNow = now ?? DateTime.now();
    return effectiveNow.isAfter(expiresAt.add(skew));
  }

  @override
  String toString() =>
      'JoinPayload(roomId: $roomId, hostAddress: $hostAddress, hostPort: $hostPort, '
      'protocolVersion: $protocolVersion, code: $code, expiresAt: $expiresAt)';
}
