// COMPATIBILITY LAYER: Provides legacy state_model.dart interface
// backed by this project's Riverpod providers.
// This file should NOT be modified - it's a pure adapter.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;

import '../application/providers/room_lifecycle_provider.dart';
import '../application/providers/create_room_flow_provider.dart';
import '../application/providers/join_room_flow_provider.dart';
import '../application/repositories/network_repository.dart';
import '../application/room/room_lifecycle.dart';

/// Conceptual lifecycle states for the SoundMesh application UI.
/// Mirrors legacy SMAppState exactly.
enum SMAppState {
  idle,
  creatingRoom,
  joiningRoom,
  roomReady,
  preparing,
  ready,
  playing,
  paused,
  stopping,
  error,
}

/// Conceptual synchronization status.
enum SMSyncStatus {
  synchronized,
  calibrating,
  preparing,
  degraded,
  resynchronizing,
  connectionLost,
  unknown,
}

/// Synchronization information suitable for application-level display.
class SyncInfo {
  const SyncInfo({
    required this.syncState,
    this.offsetMs,
    this.driftMsPerSecond,
    this.confidence,
  });

  final SMSyncStatus syncState;
  final double? offsetMs;
  final double? driftMsPerSecond;
  final double? confidence;

  SyncInfo copyWith({
    SMSyncStatus? syncState,
    double? offsetMs,
    double? driftMsPerSecond,
    double? confidence,
  }) {
    return SyncInfo(
      syncState: syncState ?? this.syncState,
      offsetMs: offsetMs ?? this.offsetMs,
      driftMsPerSecond: driftMsPerSecond ?? this.driftMsPerSecond,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() => 'SyncInfo(state: $syncState, offsetMs: $offsetMs, '
      'driftMsPerSecond: $driftMsPerSecond, confidence: $confidence)';
}

/// The high-level application state exposed to the UI.
/// Matches legacy ApplicationState exactly.
class ApplicationState {
  const ApplicationState({
    required this.state,
    this.message,
    this.isHost,
    this.roomId,
    this.joinCode,
    this.sync,
  });

  final SMAppState state;
  final String? message;
  final bool? isHost;
  final String? roomId;
  final String? joinCode;
  final SyncInfo? sync;

  ApplicationState copyWith({
    SMAppState? state,
    String? message,
    bool? isHost,
    String? roomId,
    String? joinCode,
    SyncInfo? sync,
  }) {
    return ApplicationState(
      state: state ?? this.state,
      message: message ?? this.message,
      isHost: isHost ?? this.isHost,
      roomId: roomId ?? this.roomId,
      joinCode: joinCode ?? this.joinCode,
      sync: sync ?? this.sync,
    );
  }

  @override
  String toString() => 'ApplicationState(state: $state, message: $message, '
      'isHost: $isHost, roomId: $roomId, joinCode: $joinCode, '
      'sync: $sync)';
}

/// Maps backend RoomLifecycleState to legacy SMAppState.
SMAppState _mapLifecycleState(RoomLifecycleState lifecycleState, CreateRoomFlowStatus? createStatus, JoinRoomFlowStatus? joinStatus, Object? screenState) {
  // Check for error first
  if (createStatus == CreateRoomFlowStatus.failed) return SMAppState.error;
  if (joinStatus == JoinRoomFlowStatus.failed) return SMAppState.error;

  // Check creating/joining states
  if (createStatus == CreateRoomFlowStatus.creating) return SMAppState.creatingRoom;
  if (createStatus == CreateRoomFlowStatus.hosting) return SMAppState.creatingRoom;
  if (createStatus == CreateRoomFlowStatus.listening) return SMAppState.roomReady;
  if (createStatus == CreateRoomFlowStatus.handshaking) return SMAppState.preparing;
  if (createStatus == CreateRoomFlowStatus.ready) return SMAppState.ready;

  if (joinStatus == JoinRoomFlowStatus.connecting) return SMAppState.joiningRoom;
  if (joinStatus == JoinRoomFlowStatus.handshaking) return SMAppState.preparing;
  if (joinStatus == JoinRoomFlowStatus.ready) return SMAppState.ready;

  // Map room lifecycle states - only if no create/join status is active
  // This prevents race condition where lifecycle says discoverable but create flow hasn't generated code yet
  SMAppState result;
  switch (lifecycleState) {
    case RoomLifecycleState.created:
      result = SMAppState.idle;
      break;
    case RoomLifecycleState.discoverable:
      // Only show roomReady if create flow has generated the code (listening status)
      if (createStatus == CreateRoomFlowStatus.listening) {
        result = SMAppState.roomReady;
      } else {
        result = SMAppState.creatingRoom;
      }
      break;
    case RoomLifecycleState.joining:
      result = SMAppState.joiningRoom;
      break;
    case RoomLifecycleState.ready:
      result = SMAppState.ready;
      break;
    case RoomLifecycleState.closed:
      result = SMAppState.error;
      break;
  }

  developer.log(
    '_mapLifecycleState: lifecycle=${lifecycleState.name} '
    'createStatus=${createStatus?.name} '
    'joinStatus=${joinStatus?.name} '
    '→ mapped=$result',
    name: 'SoundMesh.StateMapping',
  );

  return result;
}

/// Maps backend connection state to sync status.
SMSyncStatus _mapSyncStatus(RoomLifecycleState lifecycleState, NetworkConnectionState connectionState) {
  if (lifecycleState == RoomLifecycleState.ready) {
    return SMSyncStatus.synchronized;
  }
  if (connectionState == NetworkConnectionState.handshaking) {
    return SMSyncStatus.calibrating;
  }
  if (connectionState == NetworkConnectionState.connecting ||
      connectionState == NetworkConnectionState.listening) {
    return SMSyncStatus.preparing;
  }
  return SMSyncStatus.unknown;
}

/// Provider that exposes legacy ApplicationState interface
/// backed by this project's Riverpod providers.
final applicationStateProvider = Provider<ApplicationState>((ref) {
  final lifecycleState = ref.watch(roomLifecycleProvider);
  final createState = ref.watch(createRoomFlowProvider);
  final joinState = ref.watch(joinRoomFlowProvider);

  developer.log(
    'ApplicationState: Rebuild | '
    'lifecycle: ${lifecycleState.lifecycleState.name} | '
    'role: ${lifecycleState.role.name} | '
    'createStatus: ${createState.status.name} | '
    'joinCode: ${createState.joinCode ?? "null"} | '
    'roomId: ${lifecycleState.roomId ?? "null"}',
    name: 'SoundMesh.ApplicationState',
  );

  final mappedState = _mapLifecycleState(
    lifecycleState.lifecycleState,
    createState.status,
    joinState.status,
    null, // screenState no longer used
  );

  final isHost = lifecycleState.role == RoomRole.host;
  final syncStatus = _mapSyncStatus(lifecycleState.lifecycleState, NetworkConnectionState.ready);

  // For participants, get joinCode from joinRoomFlowProvider; for hosts, from createRoomFlowProvider
  final joinCode = isHost ? createState.joinCode : joinState.joinCode;

  return ApplicationState(
    state: mappedState,
    message: lifecycleState.errorMessage ?? createState.errorMessage ?? joinState.errorMessage,
    isHost: isHost,
    roomId: lifecycleState.roomId,
    joinCode: joinCode,
    sync: SyncInfo(
      syncState: syncStatus,
      offsetMs: null,
      driftMsPerSecond: null,
      confidence: null,
    ),
  );
});

/// Compatibility wrapper matching legacy CoreStateController interface.
class CoreStateController extends ChangeNotifier {
  CoreStateController(this._ref);

  final WidgetRef _ref;

  ApplicationState get state => _ref.read(applicationStateProvider);

  Future<void> transitionTo(SMAppState state) async {
    // No-op - state is driven by Riverpod providers
  }

  Future<void> resetToIdle() async {
    _ref.read(createRoomFlowProvider.notifier).reset();
    _ref.read(joinRoomFlowProvider.notifier).reset();
  }

  Future<void> createRoom({dynamic request}) async {
    await _ref.read(createRoomFlowProvider.notifier).createRoom();
  }

  Future<void> joinRoom({dynamic request}) async {
    await _ref.read(joinRoomFlowProvider.notifier).joinRoom();
  }

  Future<void> startCapture(dynamic request) async {
    // Not implemented yet
  }

  Future<void> prepare() async {
    // Not implemented yet
  }

  Future<void> leaveRoom() async {
    await _ref.read(roomLifecycleProvider.notifier).leaveRoom();
  }
}

/// Provides a [CoreStateController] to the widget subtree.
/// Matches legacy StateProvider exactly.
class StateProvider extends InheritedWidget {
  const StateProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  final CoreStateController controller;

  static CoreStateController of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<StateProvider>();
    if (result == null) {
      throw StateError(
        'No StateProvider found in context. '
        'Wrap your app with StateProvider(controller: ...).',
      );
    }
    return result.controller;
  }

  static CoreStateController? maybeOf(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<StateProvider>();
    return result?.controller;
  }

  @override
  bool updateShouldNotify(covariant StateProvider old) =>
      controller != old.controller;
}

/// Convenience widget that rebuilds whenever [CoreStateController.state] changes.
/// Matches legacy StateBuilder exactly.
class StateBuilder extends ConsumerWidget {
  const StateBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ApplicationState state) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(applicationStateProvider);
    return builder(context, state);
  }
}