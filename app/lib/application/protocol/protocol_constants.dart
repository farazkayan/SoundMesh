import 'dart:math';

const int currentProtocolVersion = 1;

enum ProtocolMessageType {
  hello,
  welcome,
  versionRejected,
  ping,
  pong,
  error,
  roomClosed,
  chat,
  joinRequest,
  joinAccepted,
  joinRejected,
  audioStreamInfo,
  audioPacket,
  audioStreamStart,
  audioStreamStop,
  audioBufferStatus,
  audioStreamError,
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
      case ProtocolMessageType.joinRequest:
        return 'JOIN_REQUEST';
      case ProtocolMessageType.joinAccepted:
        return 'JOIN_ACCEPTED';
      case ProtocolMessageType.joinRejected:
        return 'JOIN_REJECTED';
      case ProtocolMessageType.audioStreamInfo:
        return 'AUDIO_STREAM_INFO';
      case ProtocolMessageType.audioPacket:
        return 'AUDIO_PACKET';
      case ProtocolMessageType.audioStreamStart:
        return 'AUDIO_STREAM_START';
      case ProtocolMessageType.audioStreamStop:
        return 'AUDIO_STREAM_STOP';
      case ProtocolMessageType.audioBufferStatus:
        return 'AUDIO_BUFFER_STATUS';
      case ProtocolMessageType.audioStreamError:
        return 'AUDIO_STREAM_ERROR';
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
      case 'JOIN_REQUEST':
        return ProtocolMessageType.joinRequest;
      case 'JOIN_ACCEPTED':
        return ProtocolMessageType.joinAccepted;
      case 'JOIN_REJECTED':
        return ProtocolMessageType.joinRejected;
      case 'AUDIO_STREAM_INFO':
        return ProtocolMessageType.audioStreamInfo;
      case 'AUDIO_PACKET':
        return ProtocolMessageType.audioPacket;
      case 'AUDIO_STREAM_START':
        return ProtocolMessageType.audioStreamStart;
      case 'AUDIO_STREAM_STOP':
        return ProtocolMessageType.audioStreamStop;
      case 'AUDIO_BUFFER_STATUS':
        return ProtocolMessageType.audioBufferStatus;
      case 'AUDIO_STREAM_ERROR':
        return ProtocolMessageType.audioStreamError;
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
  // Cryptographically secure randomness is required: all 16 bytes must be
  // independent. Timestamp-derived bytes produced a single repeated value per
  // UUID and collided across consecutive calls in the same instant.
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}