import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/application/protocol/protocol_constants.dart';
import 'package:soundmesh/application/protocol/protocol_message.dart';
import 'package:soundmesh/application/providers/sync_provider.dart';
import 'package:soundmesh/application/providers/timeline_provider.dart';
import 'package:soundmesh/application/providers/discovery_provider.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
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
  final List<RoomMember> members;

  const RoomLifecycleStateData({
    this.lifecycleState = RoomLifecycleState.created,
    this.role = RoomRole.host,
    this.roomId,
    this.sessionId,
    this.participantJoined = false,
    this.closedReason,
    this.errorMessage,
    this.hostEndedRoom = false,
    this.members = const [],
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
    List<RoomMember>? members,
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
      members: members ?? this.members,
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
      if (kDebugMode) {
        debugPrint('[UILifecycle] RoomLifecycle: roomLifecycleState change -> $lifecycleState');
      }
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
      } else if (messageType == ProtocolMessageType.roomState) {
        // ROOM_STATE: update membership list from host
        _handleRoomState(message);
      } else if (messageType == ProtocolMessageType.participantLeft) {
        // PARTICIPANT_LEFT: remove participant from membership
        _handleParticipantLeft(message);
      }
    });

    _connectionStateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      if (kDebugMode) {
        debugPrint('[UILifecycle] RoomLifecycle: connectionState change -> $connState');
      }
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
          members: [], // Clear membership on full disconnect
        );
      }
    });

    _connectionErrorSubscription = _networkRepository.connectionErrorStream.listen((error) {
      state = state.copyWith(errorMessage: 'Connection error: ${error.errorCode} - ${error.errorMessage}');
    });

    // Initial sync after subscriptions are established
    _syncRoleAndParticipantState();
    // Sync membership from NetworkRepository (handles lazy initialization where ROOM_STATE was missed)
    _syncMembershipFromNetworkRepository();
  }

  /// Syncs membership from NetworkRepository's authoritative state.
  /// This handles the case where RoomLifecycleNotifier is created lazily after
  /// the initial ROOM_STATE has already been processed by NetworkRepository.
  void _syncMembershipFromNetworkRepository() {
    final membership = _networkRepository.currentMembership;
    if (membership.isNotEmpty) {
      debugPrint('[UILifecycle] RoomLifecycle: Syncing membership from NetworkRepository: ${membership.map((m) => "${m.participantId}(${m.role.name})").join(", ")}');
      state = state.copyWith(members: membership);
    }
  }

  /// Handle ROOM_STATE message: update membership list
  void _handleRoomState(ProtocolMessage message) {
    final membersPayload = message.payload?['members'] as List<dynamic>?;
    if (membersPayload == null) {
      debugPrint('[UILifecycle] ROOM_STATE missing members, ignoring');
      return;
    }
    debugPrint('[UILifecycle] Received ROOM_STATE with ${membersPayload.length} members');
    final members = <RoomMember>[];
    for (final member in membersPayload) {
      final pid = member['participantId'] as String?;
      final roleStr = member['role'] as String?;
      final displayName = member['displayName'] as String?;
      if (pid != null && roleStr != null) {
        final role = roleStr == 'HOST' ? RoomRole.host : RoomRole.participant;
        members.add(RoomMember(
          participantId: pid,
          displayName: displayName,
          role: role,
          joinedAt: DateTime.now(),
        ));
      }
    }
    // Update membership list
    state = state.copyWith(members: members, participantJoined: members.any((m) => m.role == RoomRole.participant));
    debugPrint('[UILifecycle] Updated membership: ${members.map((m) => "${m.participantId}(${m.role.name})").join(", ")}');
  }

  /// Handle PARTICIPANT_LEFT message: remove participant from membership
  void _handleParticipantLeft(ProtocolMessage message) {
    final participantId = message.payload?['participantId'] as String?;
    if (participantId == null) {
      debugPrint('[UILifecycle] PARTICIPANT_LEFT missing participantId, ignoring');
      return;
    }
    debugPrint('[UILifecycle] Received PARTICIPANT_LEFT for $participantId');
    final updatedMembers = state.members.where((m) => m.participantId != participantId).toList();
    state = state.copyWith(
      members: updatedMembers,
      participantJoined: updatedMembers.any((m) => m.role == RoomRole.participant),
    );
    debugPrint('[UILifecycle] Updated membership after leave: ${updatedMembers.map((m) => "${m.participantId}(${m.role.name})").join(", ")}');
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

  /// Reset host-ended flag when starting a new room after intentional close.
  void resetForNewRoom() {
    state = state.copyWith(hostEndedRoom: false, members: []);
  }

  Future<void> closeRoom() async {
    debugPrint('[UILifecycle] RoomLifecycle: closeRoom() called');
    await _networkRepository.closeRoom();
    // Stop discovery broadcast so the room code is no longer advertised
    await _discoveryManager.stopAll();
    state = state.copyWith(
      lifecycleState: RoomLifecycleState.closed,
      closedReason: _networkRepository.roomClosedReason ?? 'Room ended',
      hostEndedRoom: true,
    );
    // Reset the create room flow so the host can create a new room immediately
    _ref.read(createRoomFlowProvider.notifier).reset();
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