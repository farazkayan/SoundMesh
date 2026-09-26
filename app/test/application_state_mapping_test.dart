import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/presentation/state_compat.dart';

void main() {
  group('mapLifecycleState', () {
    test('maps RoomLifecycleState.closed with hostEndedRoom=true and role=host to idle', () {
      final result = mapLifecycleState(
        RoomLifecycleState.closed,
        CreateRoomFlowStatus.idle,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.host,
        hostEndedRoom: true,
      );
      expect(result, SMAppState.idle);
    });

    test('maps RoomLifecycleState.closed with hostEndedRoom=true and role=participant to error', () {
      final result = mapLifecycleState(
        RoomLifecycleState.closed,
        CreateRoomFlowStatus.idle,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.participant,
        hostEndedRoom: true,
      );
      expect(result, SMAppState.error);
    });

    test('maps RoomLifecycleState.closed with hostEndedRoom=false to error', () {
      final result = mapLifecycleState(
        RoomLifecycleState.closed,
        CreateRoomFlowStatus.idle,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.host,
        hostEndedRoom: false,
      );
      expect(result, SMAppState.error);
    });

    test('maps RoomLifecycleState.ready to ready', () {
      final result = mapLifecycleState(
        RoomLifecycleState.ready,
        CreateRoomFlowStatus.idle,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.host,
        hostEndedRoom: false,
      );
      expect(result, SMAppState.ready);
    });

    test('maps CreateRoomFlowStatus.listening to roomReady', () {
      final result = mapLifecycleState(
        RoomLifecycleState.discoverable,
        CreateRoomFlowStatus.listening,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.host,
        hostEndedRoom: false,
      );
      expect(result, SMAppState.roomReady);
    });

    test('maps CreateRoomFlowStatus.ready to ready', () {
      final result = mapLifecycleState(
        RoomLifecycleState.ready,
        CreateRoomFlowStatus.ready,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.host,
        hostEndedRoom: false,
      );
      expect(result, SMAppState.ready);
    });

    test('maps JoinRoomFlowStatus.ready to ready', () {
      final result = mapLifecycleState(
        RoomLifecycleState.ready,
        CreateRoomFlowStatus.idle,
        JoinRoomFlowStatus.ready,
        null,
        role: RoomRole.participant,
        hostEndedRoom: false,
      );
      expect(result, SMAppState.ready);
    });

    test('CreateRoomFlowStatus.failed takes precedence over lifecycle closed', () {
      final result = mapLifecycleState(
        RoomLifecycleState.closed,
        CreateRoomFlowStatus.failed,
        JoinRoomFlowStatus.idle,
        null,
        role: RoomRole.host,
        hostEndedRoom: true,
      );
      expect(result, SMAppState.error);
    });

    test('JoinRoomFlowStatus.failed takes precedence over lifecycle closed', () {
      final result = mapLifecycleState(
        RoomLifecycleState.closed,
        CreateRoomFlowStatus.idle,
        JoinRoomFlowStatus.failed,
        null,
        role: RoomRole.participant,
        hostEndedRoom: true,
      );
      expect(result, SMAppState.error);
    });
  });
}