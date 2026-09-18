import 'dart:convert';
import 'protocol_constants.dart';
import '../room/room_lifecycle.dart';

class ProtocolMessage {
  final int protocolVersion;
  final String messageId;
  final String messageType;
  final String? sessionId;
  final String senderId;
  final int generation;
  final int timestamp;
  final Map<String, dynamic>? payload;

  ProtocolMessage({
    required this.protocolVersion,
    required this.messageId,
    required this.messageType,
    this.sessionId,
    required this.senderId,
    required this.generation,
    required this.timestamp,
    this.payload,
  });

  factory ProtocolMessage.hello({
    required int protocolVersion,
    required String participantId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: protocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.hello.wireValue,
      senderId: participantId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'participantId': participantId,
      },
    );
  }

  factory ProtocolMessage.welcome({
    required int protocolVersion,
    required String sessionId,
    required String roomId,
    required String hostParticipantId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: protocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.welcome.wireValue,
      sessionId: sessionId,
      senderId: hostParticipantId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'roomId': roomId,
        'hostParticipantId': hostParticipantId,
      },
    );
  }

  factory ProtocolMessage.versionRejected({
    required int hostVersion,
    required int participantVersion,
    required String hostParticipantId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: hostVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.versionRejected.wireValue,
      senderId: hostParticipantId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'hostVersion': hostVersion,
        'participantVersion': participantVersion,
      },
    );
  }

  factory ProtocolMessage.ping({
    required String senderId,
    String? sessionId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.ping.wireValue,
      sessionId: sessionId,
      senderId: senderId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory ProtocolMessage.pong({
    required String senderId,
    String? sessionId,
    int generation = 0,
    int? timestamp,
    String? originalMessageId,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.pong.wireValue,
      sessionId: sessionId,
      senderId: senderId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: originalMessageId != null ? {'originalMessageId': originalMessageId} : null,
    );
  }

  factory ProtocolMessage.error({
    required String senderId,
    required String errorCode,
    required String errorMessage,
    String? sessionId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.error.wireValue,
      sessionId: sessionId,
      senderId: senderId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'errorCode': errorCode,
        'errorMessage': errorMessage,
      },
    );
  }

  factory ProtocolMessage.roomClosed({
    required String senderId,
    required String roomId,
    String? sessionId,
    int generation = 0,
    int? timestamp,
    String? reason,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.roomClosed.wireValue,
      sessionId: sessionId,
      senderId: senderId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'roomId': roomId,
        'reason': ?reason,
      },
    );
  }

  factory ProtocolMessage.joinRequest({
    required String participantId,
    String? displayName,
    required String sessionId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.joinRequest.wireValue,
      sessionId: sessionId,
      senderId: participantId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'participantId': participantId,
        'displayName': ?displayName,
      },
    );
  }

  factory ProtocolMessage.joinAccepted({
    required String sessionId,
    required String roomId,
    required String hostParticipantId,
    required String participantId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.joinAccepted.wireValue,
      sessionId: sessionId,
      senderId: hostParticipantId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'roomId': roomId,
        'hostParticipantId': hostParticipantId,
        'participantId': participantId,
      },
    );
  }

  factory ProtocolMessage.joinRejected({
    required String sessionId,
    required JoinRejectReason reason,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.joinRejected.wireValue,
      sessionId: sessionId,
      senderId: sessionId, // Host's session ID
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'reason': reason.wireValue,
      },
    );
  }

  factory ProtocolMessage.chat({
    required String senderId,
    required String text,
    String? sessionId,
    int generation = 0,
    int? timestamp,
  }) {
    return ProtocolMessage(
      protocolVersion: currentProtocolVersion,
      messageId: generateUuidV4(),
      messageType: ProtocolMessageType.chat.wireValue,
      sessionId: sessionId,
      senderId: senderId,
      generation: generation,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      payload: {
        'text': text,
      },
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'protocolVersion': protocolVersion,
      'messageId': messageId,
      'messageType': messageType,
      'senderId': senderId,
      'generation': generation,
      'timestamp': timestamp,
    };
    if (sessionId != null) {
      map['sessionId'] = sessionId;
    }
    if (payload != null) {
      map['payload'] = payload;
    }
    return map;
  }

  String toJsonString() => jsonEncode(toJson());

  factory ProtocolMessage.fromJson(Map<String, dynamic> json) {
    _validateRequiredFields(json);

    final protocolVersion = json['protocolVersion'] as int;
    final messageId = json['messageId'] as String;
    final messageType = json['messageType'] as String;
    final senderId = json['senderId'] as String;
    final generation = json['generation'] as int;
    final timestamp = json['timestamp'] as int;
    final sessionId = json['sessionId'] as String?;
    final payload = json['payload'] as Map<String, dynamic>?;

    _validateUuidFields(messageId, senderId, sessionId);

    return ProtocolMessage(
      protocolVersion: protocolVersion,
      messageId: messageId,
      messageType: messageType,
      sessionId: sessionId,
      senderId: senderId,
      generation: generation,
      timestamp: timestamp,
      payload: payload,
    );
  }

  static ProtocolMessage fromJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw ProtocolMessageDecodeError('Decoded JSON is not an object', rawInput: jsonString);
      }
      return ProtocolMessage.fromJson(decoded);
    } on FormatException catch (e) {
      throw ProtocolMessageDecodeError('Invalid JSON: $e', rawInput: jsonString);
    }
  }

  static void _validateRequiredFields(Map<String, dynamic> json) {
    const requiredFields = [
      'protocolVersion',
      'messageId',
      'messageType',
      'senderId',
      'generation',
      'timestamp',
    ];

    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        throw ProtocolMessageDecodeError('Missing required field: $field');
      }
      if (json[field] == null) {
        throw ProtocolMessageDecodeError('Field $field is null');
      }
    }

    if (json['protocolVersion'] is! int) {
      throw ProtocolMessageDecodeError('protocolVersion must be an integer');
    }
    if (json['messageId'] is! String) {
      throw ProtocolMessageDecodeError('messageId must be a string');
    }
    if (json['messageType'] is! String) {
      throw ProtocolMessageDecodeError('messageType must be a string');
    }
    if (json['senderId'] is! String) {
      throw ProtocolMessageDecodeError('senderId must be a string');
    }
    if (json['generation'] is! int) {
      throw ProtocolMessageDecodeError('generation must be an integer');
    }
    if (json['timestamp'] is! int) {
      throw ProtocolMessageDecodeError('timestamp must be an integer');
    }
  }

  static void _validateUuidFields(String messageId, String senderId, String? sessionId) {
    if (!isValidUuidV4(messageId)) {
      throw ProtocolMessageDecodeError('messageId must be a valid UUID v4');
    }
    if (!isValidUuidV4(senderId)) {
      throw ProtocolMessageDecodeError('senderId must be a valid UUID v4');
    }
    if (sessionId != null && !isValidUuidV4(sessionId)) {
      throw ProtocolMessageDecodeError('sessionId must be a valid UUID v4');
    }
  }

  static const _unset = Object();

  ProtocolMessage copyWith({
    int? protocolVersion,
    String? messageId,
    String? messageType,
    Object? sessionId = _unset,
    String? senderId,
    int? generation,
    int? timestamp,
    Object? payload = _unset,
  }) {
    return ProtocolMessage(
      protocolVersion: protocolVersion ?? this.protocolVersion,
      messageId: messageId ?? this.messageId,
      messageType: messageType ?? this.messageType,
      sessionId: sessionId == _unset ? this.sessionId : sessionId as String?,
      senderId: senderId ?? this.senderId,
      generation: generation ?? this.generation,
      timestamp: timestamp ?? this.timestamp,
      payload: payload == _unset ? this.payload : payload as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'ProtocolMessage(protocolVersion: $protocolVersion, messageId: $messageId, messageType: $messageType, sessionId: $sessionId, senderId: $senderId, generation: $generation, timestamp: $timestamp, payload: $payload)';
  }
}