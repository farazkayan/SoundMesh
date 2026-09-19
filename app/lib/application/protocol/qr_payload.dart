// ignore_for_file: unintended_html_in_doc_comment

/// QR payload for SoundMesh room joining.
/// Format: `soundmesh://join?room=<room-id>&host=<bootstrap-address>&port=<bootstrap-port>&version=<protocol-version>&token=<short-lived-join-token>`
class QrJoinPayload {
  const QrJoinPayload({
    required this.roomId,
    required this.host,
    required this.port,
    required this.version,
    required this.token,
  });

  final String roomId;
  final String host;
  final int port;
  final int version;
  final String token;

  /// Builds the soundmesh://join URI string.
  String toUriString() {
    final queryParams = <String, String>{
      'room': roomId,
      'host': host,
      'port': port.toString(),
      'version': version.toString(),
      'token': token,
    };
    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'soundmesh://join?$queryString';
  }

  /// Parses a soundmesh://join URI string.
  /// Returns null if the URI is invalid or missing required fields.
  static QrJoinPayload? parse(String uriString) {
    try {
      final uri = Uri.parse(uriString);

      if (uri.scheme != 'soundmesh' || uri.host != 'join') {
        return null;
      }

      final queryParams = uri.queryParameters;

      final roomId = queryParams['room'];
      final host = queryParams['host'];
      final portStr = queryParams['port'];
      final versionStr = queryParams['version'];
      final token = queryParams['token'];

      if (roomId == null ||
          roomId.isEmpty ||
          host == null ||
          host.isEmpty ||
          portStr == null ||
          portStr.isEmpty ||
          versionStr == null ||
          versionStr.isEmpty ||
          token == null ||
          token.isEmpty) {
        return null;
      }

      final port = int.tryParse(portStr);
      final version = int.tryParse(versionStr);

      if (port == null || port < 1 || port > 65535) {
        return null;
      }

      if (version == null || version < 1) {
        return null;
      }

      return QrJoinPayload(
        roomId: roomId,
        host: host,
        port: port,
        version: version,
        token: token,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() =>
      'QrJoinPayload(roomId: $roomId, host: $host, port: $port, version: $version, token: $token)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrJoinPayload &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          host == other.host &&
          port == other.port &&
          version == other.version &&
          token == other.token;

  @override
  int get hashCode =>
      roomId.hashCode ^ host.hashCode ^ port.hashCode ^ version.hashCode ^ token.hashCode;
}

/// Validates that a string is a valid soundmesh://join URI.
bool isValidQrJoinUri(String uriString) {
  return QrJoinPayload.parse(uriString) != null;
}