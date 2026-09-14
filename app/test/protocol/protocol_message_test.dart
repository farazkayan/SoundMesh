import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/protocol.dart';

void main() {
  group('ProtocolMessage', () {
    group('Serialization round-trip', () {
      test('HELLO message serializes and deserializes correctly', () {
        const participantId = '550e8400-e29b-41d4-a716-446655440000';
        final hello = ProtocolMessage.hello(
          protocolVersion: CURRENT_PROTOCOL_VERSION,
          participantId: participantId,
          generation: 0,
          timestamp: 1234567890,
        );

        final jsonString = hello.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(CURRENT_PROTOCOL_VERSION));
        expect(parsed.messageType, equals('HELLO'));
        expect(parsed.senderId, equals(participantId));
        expect(parsed.generation, equals(0));
        expect(parsed.timestamp, equals(1234567890));
        expect(parsed.payload?['participantId'], equals(participantId));
        expect(parsed.messageId, isNotNull);
        expect(_isValidUuidV4(parsed.messageId!), isTrue);
      });

      test('WELCOME message serializes and deserializes correctly', () {
        const sessionId = '660e8400-e29b-41d4-a716-446655440000';
        const roomId = '770e8400-e29b-41d4-a716-446655440000';
        const hostId = '880e8400-e29b-41d4-a716-446655440000';

        final welcome = ProtocolMessage.welcome(
          protocolVersion: CURRENT_PROTOCOL_VERSION,
          sessionId: sessionId,
          roomId: roomId,
          hostParticipantId: hostId,
          generation: 1,
          timestamp: 1234567891,
        );

        final jsonString = welcome.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(CURRENT_PROTOCOL_VERSION));
        expect(parsed.messageType, equals('WELCOME'));
        expect(parsed.sessionId, equals(sessionId));
        expect(parsed.senderId, equals(hostId));
        expect(parsed.generation, equals(1));
        expect(parsed.timestamp, equals(1234567891));
        expect(parsed.payload?['roomId'], equals(roomId));
        expect(parsed.payload?['hostParticipantId'], equals(hostId));
        expect(parsed.messageId, isNotNull);
        expect(_isValidUuidV4(parsed.messageId!), isTrue);
      });

      test('VERSION_REJECTED message serializes and deserializes correctly', () {
        const hostId = '990e8400-e29b-41d4-a716-446655440000';

        final rejected = ProtocolMessage.versionRejected(
          hostVersion: 2,
          participantVersion: 1,
          hostParticipantId: hostId,
          generation: 0,
          timestamp: 1234567892,
        );

        final jsonString = rejected.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(2));
        expect(parsed.messageType, equals('VERSION_REJECTED'));
        expect(parsed.senderId, equals(hostId));
        expect(parsed.payload?['hostVersion'], equals(2));
        expect(parsed.payload?['participantVersion'], equals(1));
      });

      test('PING message serializes and deserializes correctly', () {
        const senderId = 'aa0e8400-e29b-41d4-a716-446655440000';
        const sessionId = 'bb0e8400-e29b-41d4-a716-446655440000';

        final ping = ProtocolMessage.ping(
          senderId: senderId,
          sessionId: sessionId,
          generation: 2,
          timestamp: 1234567893,
        );

        final jsonString = ping.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(CURRENT_PROTOCOL_VERSION));
        expect(parsed.messageType, equals('PING'));
        expect(parsed.sessionId, equals(sessionId));
        expect(parsed.senderId, equals(senderId));
        expect(parsed.generation, equals(2));
        expect(parsed.timestamp, equals(1234567893));
        expect(parsed.payload, isNull);
      });

      test('PONG message serializes and deserializes correctly', () {
        const senderId = 'cc0e8400-e29b-41d4-a716-446655440000';
        const sessionId = 'dd0e8400-e29b-41d4-a716-446655440000';
        const originalId = 'ee0e8400-e29b-41d4-a716-446655440000';

        final pong = ProtocolMessage.pong(
          senderId: senderId,
          sessionId: sessionId,
          generation: 2,
          timestamp: 1234567894,
          originalMessageId: originalId,
        );

        final jsonString = pong.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(CURRENT_PROTOCOL_VERSION));
        expect(parsed.messageType, equals('PONG'));
        expect(parsed.sessionId, equals(sessionId));
        expect(parsed.senderId, equals(senderId));
        expect(parsed.payload?['originalMessageId'], equals(originalId));
      });

      test('ERROR message serializes and deserializes correctly', () {
        const senderId = 'ff0e8400-e29b-41d4-a716-446655440000';
        const sessionId = '000e8400-e29b-41d4-a716-446655440000';

        final error = ProtocolMessage.error(
          senderId: senderId,
          errorCode: 'TEST_ERROR',
          errorMessage: 'Something went wrong',
          sessionId: sessionId,
          generation: 3,
          timestamp: 1234567895,
        );

        final jsonString = error.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(CURRENT_PROTOCOL_VERSION));
        expect(parsed.messageType, equals('ERROR'));
        expect(parsed.sessionId, equals(sessionId));
        expect(parsed.senderId, equals(senderId));
        expect(parsed.payload?['errorCode'], equals('TEST_ERROR'));
        expect(parsed.payload?['errorMessage'], equals('Something went wrong'));
      });

      test('ROOM_CLOSED message serializes and deserializes correctly', () {
        const senderId = '110e8400-e29b-41d4-a716-446655440000';
        const roomId = '220e8400-e29b-41d4-a716-446655440000';
        const sessionId = '330e8400-e29b-41d4-a716-446655440000';

        final closed = ProtocolMessage.roomClosed(
          senderId: senderId,
          roomId: roomId,
          sessionId: sessionId,
          generation: 4,
          timestamp: 1234567896,
        );

        final jsonString = closed.toJsonString();
        final parsed = ProtocolMessage.fromJsonString(jsonString);

        expect(parsed.protocolVersion, equals(CURRENT_PROTOCOL_VERSION));
        expect(parsed.messageType, equals('ROOM_CLOSED'));
        expect(parsed.sessionId, equals(sessionId));
        expect(parsed.senderId, equals(senderId));
        expect(parsed.payload?['roomId'], equals(roomId));
      });
    });

    group('Malformed JSON handling', () {
      test('throws ProtocolMessageDecodeError for invalid JSON', () {
        expect(
          () => ProtocolMessage.fromJsonString('not valid json'),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for missing required fields', () {
        final jsonString = '{"protocolVersion": 1}';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for null required fields', () {
        final jsonString = '{"protocolVersion": 1, "messageId": null, "messageType": "HELLO", "senderId": "id", "generation": 0, "timestamp": 123}';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for wrong field types', () {
        final jsonString = '{"protocolVersion": "not an int", "messageId": "id", "messageType": "HELLO", "senderId": "id", "generation": 0, "timestamp": 123}';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for invalid UUID v4', () {
        final jsonString = '{"protocolVersion": 1, "messageId": "not-a-uuid", "messageType": "HELLO", "senderId": "550e8400-e29b-41d4-a716-446655440000", "generation": 0, "timestamp": 123}';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for invalid senderId UUID', () {
        final jsonString = '{"protocolVersion": 1, "messageId": "550e8400-e29b-41d4-a716-446655440000", "messageType": "HELLO", "senderId": "not-a-uuid", "generation": 0, "timestamp": 123}';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for invalid sessionId UUID', () {
        final jsonString = '{"protocolVersion": 1, "messageId": "550e8400-e29b-41d4-a716-446655440000", "messageType": "HELLO", "senderId": "550e8400-e29b-41d4-a716-446655440000", "sessionId": "not-a-uuid", "generation": 0, "timestamp": 123}';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });

      test('throws ProtocolMessageDecodeError for non-object JSON', () {
        final jsonString = '["array", "not", "object"]';
        expect(
          () => ProtocolMessage.fromJsonString(jsonString),
          throwsA(isA<ProtocolMessageDecodeError>()),
        );
      });
    });

    group('UUID v4 validation', () {
      test('valid UUID v4 passes validation', () {
        expect(_isValidUuidV4('550e8400-e29b-41d4-a716-446655440000'), isTrue);
        expect(_isValidUuidV4('660e8400-e29b-41d4-a716-446655440000'), isTrue);
        expect(_isValidUuidV4('ffffffff-ffff-4fff-8fff-ffffffffffff'), isTrue);
      });

      test('invalid UUID v4 fails validation', () {
        expect(_isValidUuidV4('not-a-uuid'), isFalse);
        expect(_isValidUuidV4('550e8400-e29b-41d4-a716-44665544000'), isFalse); // too short
        expect(_isValidUuidV4('550e8400-e29b-41d4-a716-4466554400000'), isFalse); // too long
        expect(_isValidUuidV4('550e8400-e29b-31d4-a716-446655440000'), isFalse); // version 3
        expect(_isValidUuidV4('550e8400-e29b-51d4-a716-446655440000'), isFalse); // version 5
        expect(_isValidUuidV4('550e8400-e29b-41d4-7716-446655440000'), isFalse); // variant not 8/9/a/b
      });
    });

    group('Message type wire values', () {
      test('ProtocolMessageType wire values are correct', () {
        expect(ProtocolMessageType.hello.wireValue, equals('HELLO'));
        expect(ProtocolMessageType.welcome.wireValue, equals('WELCOME'));
        expect(ProtocolMessageType.versionRejected.wireValue, equals('VERSION_REJECTED'));
        expect(ProtocolMessageType.ping.wireValue, equals('PING'));
        expect(ProtocolMessageType.pong.wireValue, equals('PONG'));
        expect(ProtocolMessageType.error.wireValue, equals('ERROR'));
        expect(ProtocolMessageType.roomClosed.wireValue, equals('ROOM_CLOSED'));
      });

      test('ProtocolMessageType fromWireValue works', () {
        expect(ProtocolMessageTypeX.fromWireValue('HELLO'), equals(ProtocolMessageType.hello));
        expect(ProtocolMessageTypeX.fromWireValue('WELCOME'), equals(ProtocolMessageType.welcome));
        expect(ProtocolMessageTypeX.fromWireValue('VERSION_REJECTED'), equals(ProtocolMessageType.versionRejected));
        expect(ProtocolMessageTypeX.fromWireValue('PING'), equals(ProtocolMessageType.ping));
        expect(ProtocolMessageTypeX.fromWireValue('PONG'), equals(ProtocolMessageType.pong));
        expect(ProtocolMessageTypeX.fromWireValue('ERROR'), equals(ProtocolMessageType.error));
        expect(ProtocolMessageTypeX.fromWireValue('ROOM_CLOSED'), equals(ProtocolMessageType.roomClosed));
        expect(ProtocolMessageTypeX.fromWireValue('UNKNOWN'), isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with modified fields', () {
        const participantId = '550e8400-e29b-41d4-a716-446655440000';
        final hello = ProtocolMessage.hello(
          protocolVersion: CURRENT_PROTOCOL_VERSION,
          participantId: participantId,
          generation: 0,
        );

        final copied = hello.copyWith(generation: 5, timestamp: 999999999);

        expect(copied.generation, equals(5));
        expect(copied.timestamp, equals(999999999));
        expect(copied.protocolVersion, equals(hello.protocolVersion));
        expect(copied.messageId, equals(hello.messageId));
        expect(copied.senderId, equals(hello.senderId));
      });
    });
  });
}

bool _isValidUuidV4(String value) {
  final uuidV4Regex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  return uuidV4Regex.hasMatch(value);
}