import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';

void main() {
  group('ProtocolMessage JOIN_REQUEST', () {
    test('serializes and deserializes correctly', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';
      const participantId = '770e8400-e29b-41d4-a716-446655440000';

      final message = ProtocolMessage.joinRequest(
        participantId: participantId,
        displayName: 'Test User',
        sessionId: sessionId,
        generation: 1,
      );

      final json = message.toJson();
      final decoded = ProtocolMessage.fromJson(json);

      expect(decoded.protocolVersion, 1);
      expect(decoded.messageType, 'JOIN_REQUEST');
      expect(decoded.sessionId, sessionId);
      expect(decoded.senderId, participantId);
      expect(decoded.generation, 1);
      expect(decoded.payload?['participantId'], participantId);
      expect(decoded.payload?['displayName'], 'Test User');
    });

    test('serializes without displayName', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';
      const participantId = '770e8400-e29b-41d4-a716-446655440000';

      final message = ProtocolMessage.joinRequest(
        participantId: participantId,
        displayName: null,
        sessionId: sessionId,
      );

      final json = message.toJson();
      final decoded = ProtocolMessage.fromJson(json);

      expect(decoded.payload?['participantId'], participantId);
      expect(decoded.payload?.containsKey('displayName'), isFalse);
    });

    test('wire value is correct', () {
      expect(ProtocolMessageType.joinRequest.wireValue, 'JOIN_REQUEST');
      expect(ProtocolMessageTypeX.fromWireValue('JOIN_REQUEST'), ProtocolMessageType.joinRequest);
    });
  });

  group('ProtocolMessage JOIN_ACCEPTED', () {
    test('serializes and deserializes correctly', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';
      const roomId = '880e8400-e29b-41d4-a716-446655440000';
      const hostParticipantId = '770e8400-e29b-41d4-a716-446655440000';
      const participantId = '990e8400-e29b-41d4-a716-446655440000';

      final message = ProtocolMessage.joinAccepted(
        sessionId: sessionId,
        roomId: roomId,
        hostParticipantId: hostParticipantId,
        participantId: participantId,
        generation: 1,
      );

      final json = message.toJson();
      final decoded = ProtocolMessage.fromJson(json);

      expect(decoded.protocolVersion, 1);
      expect(decoded.messageType, 'JOIN_ACCEPTED');
      expect(decoded.sessionId, sessionId);
      expect(decoded.senderId, hostParticipantId);
      expect(decoded.generation, 1);
      expect(decoded.payload?['roomId'], roomId);
      expect(decoded.payload?['hostParticipantId'], hostParticipantId);
      expect(decoded.payload?['participantId'], participantId);
    });

    test('wire value is correct', () {
      expect(ProtocolMessageType.joinAccepted.wireValue, 'JOIN_ACCEPTED');
      expect(ProtocolMessageTypeX.fromWireValue('JOIN_ACCEPTED'), ProtocolMessageType.joinAccepted);
    });
  });

  group('ProtocolMessage JOIN_REJECTED', () {
    test('serializes and deserializes correctly', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';

      final message = ProtocolMessage.joinRejected(
        sessionId: sessionId,
        reason: JoinRejectReason.roomFull,
        generation: 1,
      );

      final json = message.toJson();
      final decoded = ProtocolMessage.fromJson(json);

      expect(decoded.protocolVersion, 1);
      expect(decoded.messageType, 'JOIN_REJECTED');
      expect(decoded.sessionId, sessionId);
      expect(decoded.senderId, sessionId); // Host's session ID
      expect(decoded.generation, 1);
      expect(decoded.payload?['reason'], 'ROOM_FULL');
    });

    test('serializes with different reasons', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';

      final reasons = [
        JoinRejectReason.roomFull,
        JoinRejectReason.versionMismatch,
        JoinRejectReason.closed,
        JoinRejectReason.internalError,
      ];

      for (final reason in reasons) {
        final message = ProtocolMessage.joinRejected(
          sessionId: sessionId,
          reason: reason,
        );

        final json = message.toJson();
        final decoded = ProtocolMessage.fromJson(json);
        expect(decoded.payload?['reason'], reason.wireValue);
      }
    });

    test('wire value is correct', () {
      expect(ProtocolMessageType.joinRejected.wireValue, 'JOIN_REJECTED');
      expect(ProtocolMessageTypeX.fromWireValue('JOIN_REJECTED'), ProtocolMessageType.joinRejected);
    });
  });

  group('ProtocolMessage ROOM_CLOSED with reason', () {
    test('serializes and deserializes with reason', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';
      const roomId = '880e8400-e29b-41d4-a716-446655440000';
      const senderId = '770e8400-e29b-41d4-a716-446655440000';
      const reason = 'Host ended the room';

      final message = ProtocolMessage.roomClosed(
        senderId: senderId,
        roomId: roomId,
        sessionId: sessionId,
        reason: reason,
      );

      final json = message.toJson();
      final decoded = ProtocolMessage.fromJson(json);

      expect(decoded.protocolVersion, 1);
      expect(decoded.messageType, 'ROOM_CLOSED');
      expect(decoded.sessionId, sessionId);
      expect(decoded.senderId, senderId);
      expect(decoded.payload?['roomId'], roomId);
      expect(decoded.payload?['reason'], reason);
    });

    test('serializes without reason', () {
      const sessionId = '660e8400-e29b-41d4-a716-446655440000';
      const roomId = '880e8400-e29b-41d4-a716-446655440000';
      const senderId = '770e8400-e29b-41d4-a716-446655440000';

      final message = ProtocolMessage.roomClosed(
        senderId: senderId,
        roomId: roomId,
        sessionId: sessionId,
      );

      final json = message.toJson();
      final decoded = ProtocolMessage.fromJson(json);

      expect(decoded.payload?['roomId'], roomId);
      expect(decoded.payload?.containsKey('reason'), isFalse);
    });
  });
}