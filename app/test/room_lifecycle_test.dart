import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';

void main() {
  group('RoomLifecycleState', () {
    test('enum values are correct', () {
      expect(RoomLifecycleState.values, [
        RoomLifecycleState.created,
        RoomLifecycleState.discoverable,
        RoomLifecycleState.joining,
        RoomLifecycleState.ready,
        RoomLifecycleState.closed,
      ]);
    });

    test('display names are correct', () {
      expect(RoomLifecycleState.created.displayName, 'Creating...');
      expect(RoomLifecycleState.discoverable.displayName, 'Waiting for participant...');
      expect(RoomLifecycleState.joining.displayName, 'Joining...');
      expect(RoomLifecycleState.ready.displayName, 'Ready');
      expect(RoomLifecycleState.closed.displayName, 'Closed');
    });

    test('descriptions are correct', () {
      expect(RoomLifecycleState.created.description, 'Room object exists, not yet discoverable');
      expect(RoomLifecycleState.discoverable.description, 'Host is listening for participants');
      expect(RoomLifecycleState.joining.description, 'Participant handshake complete, join request pending');
      expect(RoomLifecycleState.ready.description, 'Participant formally joined the room');
      expect(RoomLifecycleState.closed.description, 'Room has ended');
    });
  });

  group('RoomRole', () {
    test('enum values are correct', () {
      expect(RoomRole.values, [RoomRole.host, RoomRole.participant]);
    });
  });

  group('RoomMember', () {
    test('can be created with all fields', () {
      final member = RoomMember(
        participantId: 'test-id',
        displayName: 'Test User',
        role: RoomRole.participant,
        joinedAt: DateTime.now(),
      );
      expect(member.participantId, 'test-id');
      expect(member.displayName, 'Test User');
      expect(member.role, RoomRole.participant);
    });

    test('displayName can be null', () {
      final member = RoomMember(
        participantId: 'test-id',
        displayName: null,
        role: RoomRole.host,
        joinedAt: DateTime.now(),
      );
      expect(member.displayName, null);
    });
  });

  group('JoinRejectReason', () {
    test('enum values are correct', () {
      expect(JoinRejectReason.values, [
        JoinRejectReason.roomFull,
        JoinRejectReason.versionMismatch,
        JoinRejectReason.closed,
        JoinRejectReason.internalError,
      ]);
    });

    test('wire values are correct', () {
      expect(JoinRejectReason.roomFull.wireValue, 'ROOM_FULL');
      expect(JoinRejectReason.versionMismatch.wireValue, 'VERSION_MISMATCH');
      expect(JoinRejectReason.closed.wireValue, 'CLOSED');
      expect(JoinRejectReason.internalError.wireValue, 'INTERNAL_ERROR');
    });

    test('fromWireValue works correctly', () {
      expect(JoinRejectReasonX.fromWireValue('ROOM_FULL'), JoinRejectReason.roomFull);
      expect(JoinRejectReasonX.fromWireValue('VERSION_MISMATCH'), JoinRejectReason.versionMismatch);
      expect(JoinRejectReasonX.fromWireValue('CLOSED'), JoinRejectReason.closed);
      expect(JoinRejectReasonX.fromWireValue('INTERNAL_ERROR'), JoinRejectReason.internalError);
      expect(JoinRejectReasonX.fromWireValue('UNKNOWN'), null);
    });
  });
}