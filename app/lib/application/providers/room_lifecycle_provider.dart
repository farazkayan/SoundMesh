import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/network_repository.dart';
import '../room/room_lifecycle.dart';
import '../protocol/protocol_constants.dart';

class RoomLifecycleStateData {
  final RoomLifecycleState lifecycleState;
  final RoomRole role;
  final String? roomId;
  final String? sessionId;
  final bool participantJoined;
  final String? closedReason;

  const RoomLifecycleStateData({
    this.lifecycleState = RoomLifecycleState.created,
    this.role = RoomRole.host,
    this.roomId,
    this.sessionId,
    this.participantJoined = false,
    this.closedReason,
  });

  RoomLifecycleStateData copyWith({
    RoomLifecycleState? lifecycleState,
    RoomRole? role,
    String? roomId,
    String? sessionId,
    bool? participantJoined,
    String? closedReason,
  }) {
    return RoomLifecycleStateData(
      lifecycleState: lifecycleState ?? this.lifecycleState,
      role: role ?? this.role,
      roomId: roomId ?? this.roomId,
      sessionId: sessionId ?? this.sessionId,
      participantJoined: participantJoined ?? this.participantJoined,
      closedReason: closedReason ?? this.closedReason,
    );
  }
}

class RoomLifecycleNotifier extends StateNotifier<RoomLifecycleStateData> {
  final NetworkRepository _networkRepository;
  StreamSubscription? _lifecycleSubscription;
  StreamSubscription? _protocolMessageSubscription;
  StreamSubscription? _connectionStateSubscription;

  RoomLifecycleNotifier(this._networkRepository) : super(const RoomLifecycleStateData()) {
    _lifecycleSubscription = _networkRepository.roomLifecycleStateStream.listen((lifecycleState) {
      debugPrint('[UILifecycle] RoomLifecycle: roomLifecycleState change -> $lifecycleState');
      state = state.copyWith(lifecycleState: lifecycleState);
    });

    _protocolMessageSubscription = _networkRepository.protocolMessageStream.listen((message) {
      final messageType = ProtocolMessageTypeX.fromWireValue(message.messageType);
      if (messageType == ProtocolMessageType.roomClosed) {
        final reason = message.payload?['reason'] as String?;
        state = state.copyWith(closedReason: reason ?? 'Room closed');
      } else if (messageType == ProtocolMessageType.joinAccepted) {
        state = state.copyWith(
          sessionId: _networkRepository.sessionId,
          roomId: _networkRepository.roomId,
        );
      } else if (messageType == ProtocolMessageType.joinRejected) {
        // Raw wire values must not leak into UI-facing state.
        final reasonStr = message.payload?['reason'] as String?;
        final reason = JoinRejectReasonX.fromWireValue(reasonStr ?? '') ?? JoinRejectReason.internalError;
        state = state.copyWith(closedReason: reason.friendlyMessage);
      }
    });

    _connectionStateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      debugPrint('[UILifecycle] RoomLifecycle: connectionState change -> $connState');
      // Update roomId and sessionId when they become available
      if (connState == NetworkConnectionState.ready) {
        state = state.copyWith(
          sessionId: _networkRepository.sessionId,
          roomId: _networkRepository.roomId,
        );
      }
    });

    // Initialize role from network repository
    state = state.copyWith(role: _networkRepository.roomRole);
  }

  void setParticipantDisplayName(String? displayName) {
    _networkRepository.setParticipantDisplayName(displayName);
  }

  Future<void> closeRoom() async {
    debugPrint('[UILifecycle] RoomLifecycle: closeRoom() called');
    await _networkRepository.closeRoom();
    state = state.copyWith(
      lifecycleState: RoomLifecycleState.closed,
      closedReason: _networkRepository.roomClosedReason ?? 'Room ended',
    );
  }

  Future<void> leaveRoom() async {
    debugPrint('[UILifecycle] RoomLifecycle: leaveRoom() called');
    await _networkRepository.leaveRoom();
    state = state.copyWith(
      lifecycleState: RoomLifecycleState.closed,
      closedReason: _networkRepository.roomClosedReason ?? 'You left the room',
    );
  }

  @override
  void dispose() {
    _lifecycleSubscription?.cancel();
    _protocolMessageSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }
}

final roomLifecycleProvider = StateNotifierProvider<RoomLifecycleNotifier, RoomLifecycleStateData>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  return RoomLifecycleNotifier(networkRepo);
});