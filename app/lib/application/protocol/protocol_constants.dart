const int CURRENT_PROTOCOL_VERSION = 1;

enum ProtocolMessageType {
  hello,
  welcome,
  versionRejected,
  ping,
  pong,
  error,
  roomClosed,
  chat,
}

extension ProtocolMessageTypeX on ProtocolMessageType {
  String get wireValue {
    switch (this) {
      case ProtocolMessageType.hello:
        return 'HELLO';
      case ProtocolMessageType.welcome:
        return 'WELCOME';
      case ProtocolMessageType.versionRejected:
        return 'VERSION_REJECTED';
      case ProtocolMessageType.ping:
        return 'PING';
      case ProtocolMessageType.pong:
        return 'PONG';
      case ProtocolMessageType.error:
        return 'ERROR';
      case ProtocolMessageType.roomClosed:
        return 'ROOM_CLOSED';
      case ProtocolMessageType.chat:
        return 'CHAT';
    }
  }

  static ProtocolMessageType? fromWireValue(String value) {
    switch (value) {
      case 'HELLO':
        return ProtocolMessageType.hello;
      case 'WELCOME':
        return ProtocolMessageType.welcome;
      case 'VERSION_REJECTED':
        return ProtocolMessageType.versionRejected;
      case 'PING':
        return ProtocolMessageType.ping;
      case 'PONG':
        return ProtocolMessageType.pong;
      case 'ERROR':
        return ProtocolMessageType.error;
      case 'ROOM_CLOSED':
        return ProtocolMessageType.roomClosed;
      case 'CHAT':
        return ProtocolMessageType.chat;
      default:
        return null;
    }
  }
}

class ProtocolMessageDecodeError implements Exception {
  final String message;
  final String? rawInput;

  ProtocolMessageDecodeError(this.message, {this.rawInput});

  @override
  String toString() => 'ProtocolMessageDecodeError: $message${rawInput != null ? ' (input: $rawInput)' : ''}';
}

class ProtocolVersionMismatchError implements Exception {
  final int hostVersion;
  final int participantVersion;

  ProtocolVersionMismatchError({
    required this.hostVersion,
    required this.participantVersion,
  });

  @override
  String toString() => 'ProtocolVersionMismatchError: host v$hostVersion != participant v$participantVersion';
}

bool isValidUuidV4(String value) {
  final uuidV4Regex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  return uuidV4Regex.hasMatch(value);
}

String generateUuidV4() {
  final random = List<int>.generate(16, (_) => DateTime.now().microsecondsSinceEpoch ^ DateTime.now().millisecondsSinceEpoch ^ (0xFFFF & DateTime.now().microsecondsSinceEpoch));
  random[6] = (random[6] & 0x0f) | 0x40;
  random[8] = (random[8] & 0x3f) | 0x80;
  final bytes = random.map((e) => e & 0xff).toList();
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}