import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/application/protocol/protocol_constants.dart';
import 'package:soundmesh/application/providers/sync_provider.dart';
import 'package:soundmesh/application/providers/timeline_provider.dart';
import 'package:soundmesh/application/providers/discovery_provider.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';

class RoomLifecycleStateData {
  final RoomLifecycleState lifecycleState;
  final RoomRole role;
  final String? roomId;
  final String? sessionId;
  final bool participantJoined;
  final String? closedReason;
  final String? errorMessage;
  final bool hostEndedRoom;

  const RoomLifecycleStateData({
    this.lifecycleState = RoomLifecycleState.created,
    this.role = RoomRole.host,
    this.roomId,
    this.sessionId,
    this.participantJoined = false,
    this.closedReason,
    this.errorMessage,
    this.hostEndedRoom = false,
  });

  RoomLifecycleStateData copyWith({
    RoomLifecycleState? lifecycleState,
    RoomRole? role,
    String? roomId,
    String? sessionId,
    bool? participantJoined,
    String? closedReason,
    String? errorMessage,
    bool? hostEndedRoom,
    bool clearErrorMessage = false,
  }) {
    return RoomLifecycleStateData(
      lifecycleState: lifecycleState ?? this.lifecycleState,
      role: role ?? this.role,
      roomId: roomId ?? this.roomId,
      sessionId: sessionId ?? this.sessionId,
      participantJoined: participantJoined ?? this.participantJoined,
      closedReason: closedReason ?? this.closedReason,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      hostEndedRoom: hostEndedRoom ?? this.hostEndedRoom,
    );
  }
}

class RoomLifecycleNotifier extends StateNotifier<RoomLifecycleStateData> {
  final NetworkRepository _networkRepository;
  final DiscoveryManager _discoveryManager;
  final Ref _ref;
  StreamSubscription? _lifecycleSubscription;
  StreamSubscription? _protocolMessageSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _connectionErrorSubscription;

  RoomLifecycleNotifier(this._networkRepository, this._discoveryManager, this._ref) : super(const RoomLifecycleStateData()) {
    // Watch sync lifecycle to ensure sync repository is active when network is connected
    _ref.watch(syncLifecycleProvider);
    // Watch timeline scheduler to enable Phase 13 scheduling
    _ref.watch(timelineSchedulerProvider);

    _lifecycleSubscription = _networkRepository.roomLifecycleStateStream.listen((lifecycleState) {
      debugPrint('[UILifecycle] RoomLifecycle: roomLifecycleState change -> $lifecycleState');
      state = state.copyWith(lifecycleState: lifecycleState);
    });

    _protocolMessageSubscription = _networkRepository.protocolMessageStream.listen((message) {
      final messageType = ProtocolMessageTypeX.fromWireValue(message.messageType);
      if (messageType == ProtocolMessageType.roomClosed) {
        final reason = message.payload?['reason'] as String?;
        final isHostEnded = reason == 'Host ended the room';
        state = state.copyWith(
          closedReason: reason ?? 'Room closed',
          hostEndedRoom: isHostEnded,
        );
      } else if (messageType == ProtocolMessageType.joinAccepted) {
        state = state.copyWith(
          sessionId: _networkRepository.sessionId,
          roomId: _networkRepository.roomId,
        );
        // Participant side: JOIN_ACCEPTED means we formally joined; sync role and participant state
        _syncRoleAndParticipantState();
      } else if (messageType == ProtocolMessageType.joinRejected) {
        // Raw wire values must not leak into UI-facing state.
        final reasonStr = message.payload?['reason'] as String?;
        final reason = JoinRejectReasonX.fromWireValue(reasonStr ?? '') ?? JoinRejectReason.internalError;
        state = state.copyWith(closedReason: reason.friendlyMessage);
      } else if (messageType == ProtocolMessageType.joinRequest) {
        // Host side: JOIN_REQUEST received means a participant is joining; sync participant state
        _syncRoleAndParticipantState();
      }
    });

    _connectionStateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      debugPrint('[UILifecycle] RoomLifecycle: connectionState change -> $connState');
      if (connState == NetworkConnectionState.ready) {
        state = state.copyWith(
          sessionId: _networkRepository.sessionId,
          roomId: _networkRepository.roomId,
        );
        // Connection ready: both role and participantJoined are now stable
        _syncRoleAndParticipantState();
      } else if (connState == NetworkConnectionState.disconnected) {
        // Disconnected: reset participantJoined and room/session IDs (role will be reset on next connect/host)
        state = state.copyWith(
          participantJoined: false,
          roomId: null,
          sessionId: null,
        );
      }
    });

    _connectionErrorSubscription = _networkRepository.connectionErrorStream.listen((error) {
      state = state.copyWith(errorMessage: 'Connection error: ${error.errorCode} - ${error.errorMessage}');
    });

    // Initial sync after subscriptions are established
    _syncRoleAndParticipantState();
  }

  /// Reads current role and participantJoined from NetworkRepository and updates state.
  /// Called at synchronization points where these values are guaranteed to be accurate.
  void _syncRoleAndParticipantState() {
    final role = _networkRepository.roomRole;
    final participantJoined = _networkRepository.participantJoined;
    debugPrint('[UILifecycle] RoomLifecycle: _syncRoleAndParticipantState -> role=$role, participantJoined=$participantJoined');
    state = state.copyWith(role: role, participantJoined: participantJoined);
  }

  /// Public method to explicitly sync role and participantJoined from NetworkRepository.
  /// Called by flow providers after intentional role changes (startHosting, connectToHost).
  void syncRoleAndParticipantState() {
    _syncRoleAndParticipantState();
  }

  void setParticipantDisplayName(String? displayName) {
    _networkRepository.setParticipantDisplayName(displayName);
  }

  Future<void> closeRoom() async {
    debugPrint('[UILifecycle] RoomLifecycle: closeRoom() called');
    await _networkRepository.closeRoom();
    // Stop discovery broadcast so the room code is no longer advertised
    await _discoveryManager.stopAll();
    state = state.copyWith(
      lifecycleState: RoomLifecycleState.closed,
      closedReason: _networkRepository.roomClosedReason ?? 'Room ended',
      hostEndedRoom: false,
    );
  }

  Future<void> leaveRoom() async {
    debugPrint('[UILifecycle] RoomLifecycle: leaveRoom() called');
    await _networkRepository.leaveRoom();
    state = state.copyWith(
      lifecycleState: RoomLifecycleState.closed,
      closedReason: _networkRepository.roomClosedReason ?? 'You left the room',
      hostEndedRoom: false,
    );
  }

  @override
  void dispose() {
    _lifecycleSubscription?.cancel();
    _protocolMessageSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    super.dispose();
  }
}

final roomLifecycleProvider = StateNotifierProvider<RoomLifecycleNotifier, RoomLifecycleStateData>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  final discoveryManager = ref.watch(discoveryManagerProvider);
  return RoomLifecycleNotifier(networkRepo, discoveryManager, ref);
});