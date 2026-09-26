import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/network_repository.dart';
import '../protocol.dart';
import '../room/room_lifecycle.dart';
import '../../infrastructure/discovery/discovery_types.dart';
import '../../infrastructure/discovery/discovery_manager.dart';
import '../providers/discovery_provider.dart';
import 'room_lifecycle_provider.dart';

enum CreateRoomFlowStatus {
  idle,
  creating,
  hosting,
  listening,
  handshaking,
  ready,
  failed,
}

class CreateRoomFlowState {
  final CreateRoomFlowStatus status;
  final String roomName;
  final String? localIpAddress;
  final int? port;
  final String? errorMessage;
  final NetworkConnectionState connectionState;
  final RoomLifecycleState roomLifecycleState;
  final String? sessionId;
  final String? roomId;
  final String? joinCode;

  const CreateRoomFlowState({
    this.status = CreateRoomFlowStatus.idle,
    this.roomName = '',
    this.localIpAddress,
    this.port = 8765,
    this.errorMessage,
    this.connectionState = NetworkConnectionState.disconnected,
    this.roomLifecycleState = RoomLifecycleState.created,
    this.sessionId,
    this.roomId,
    this.joinCode,
  });

  CreateRoomFlowState copyWith({
    CreateRoomFlowStatus? status,
    String? roomName,
    String? localIpAddress,
    int? port,
    String? errorMessage,
    NetworkConnectionState? connectionState,
    RoomLifecycleState? roomLifecycleState,
    String? sessionId,
    String? roomId,
    String? joinCode,
  }) {
    return CreateRoomFlowState(
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      localIpAddress: localIpAddress ?? this.localIpAddress,
      port: port ?? this.port,
      errorMessage: errorMessage,
      connectionState: connectionState ?? this.connectionState,
      roomLifecycleState: roomLifecycleState ?? this.roomLifecycleState,
      sessionId: sessionId ?? this.sessionId,
      roomId: roomId ?? this.roomId,
      joinCode: joinCode ?? this.joinCode,
    );
  }
}

class CreateRoomFlowNotifier extends StateNotifier<CreateRoomFlowState> {
  final NetworkRepository _networkRepository;
  final DiscoveryManager _discoveryManager;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _protocolMessageSubscription;
  StreamSubscription? _connectionErrorSubscription;
  bool _createRoomInProgress = false;

  CreateRoomFlowNotifier(this._networkRepository, this._discoveryManager)
      : super(const CreateRoomFlowState()) {
    _stateSubscription = _networkRepository.connectionStateStream.listen((
      connState,
    ) {
      debugPrint('[UILifecycle] CreateRoomFlow: connectionState change -> $connState (current status: ${state.status})');
      state = state.copyWith(connectionState: connState);
      _handleConnectionStateChange(connState);
    });

    _protocolMessageSubscription = _networkRepository.protocolMessageStream.listen(
      (protocolMessage) {
        _handleProtocolMessage(protocolMessage);
      },
    );

    _connectionErrorSubscription = _networkRepository.connectionErrorStream.listen(
      (error) {
        debugPrint('[UILifecycle] CreateRoomFlow: connectionError -> $error');
        _handleConnectionError(error);
      },
    );
  }

  void _handleConnectionError(ConnectionError error) {
    String userMessage;
    switch (error.errorCode) {
      case 'CONNECTION_REFUSED':
        userMessage = 'Could not start hosting — port may be in use.';
        break;
      case 'CONNECTION_TIMEOUT':
        userMessage = 'Hosting timed out.';
        break;
      case 'UNKNOWN_HOST':
        userMessage = 'Could not determine local IP address.';
        break;
      case 'SOCKET_ERROR':
        userMessage = 'Network error: ${error.errorMessage}';
        break;
      case 'CONNECTION_FAILED':
      default:
        userMessage = 'Failed to start hosting: ${error.errorMessage}';
        break;
    }
    
    if (state.status == CreateRoomFlowStatus.hosting ||
        state.status == CreateRoomFlowStatus.listening ||
        state.status == CreateRoomFlowStatus.handshaking) {
      state = state.copyWith(
        status: CreateRoomFlowStatus.failed,
        errorMessage: userMessage,
      );
    }
  }

  void _handleConnectionStateChange(NetworkConnectionState connState) {
    switch (connState) {
      case NetworkConnectionState.connected:
        if (state.status == CreateRoomFlowStatus.hosting) {
          state = state.copyWith(status: CreateRoomFlowStatus.listening);
        }
        break;
      case NetworkConnectionState.listening:
        if (state.status == CreateRoomFlowStatus.hosting ||
            state.status == CreateRoomFlowStatus.creating) {
          state = state.copyWith(status: CreateRoomFlowStatus.listening);
        }
        break;
      case NetworkConnectionState.handshaking:
        if (state.status == CreateRoomFlowStatus.hosting ||
            state.status == CreateRoomFlowStatus.listening) {
          state = state.copyWith(status: CreateRoomFlowStatus.handshaking);
        }
        break;
      case NetworkConnectionState.ready:
        if (state.status == CreateRoomFlowStatus.handshaking) {
          state = state.copyWith(
            status: CreateRoomFlowStatus.ready,
            sessionId: _networkRepository.sessionId,
            roomId: _networkRepository.roomId,
          );
        }
        break;
      case NetworkConnectionState.failed:
        // Only set generic "Handshake failed" if we don't already have a specific connection error
        if (state.status == CreateRoomFlowStatus.hosting ||
            state.status == CreateRoomFlowStatus.listening ||
            state.status == CreateRoomFlowStatus.handshaking) {
          if (state.errorMessage == null || state.errorMessage == 'Failed to initiate connection') {
            state = state.copyWith(
              status: CreateRoomFlowStatus.failed,
              errorMessage: 'Handshake failed',
            );
          }
        }
        break;
      case NetworkConnectionState.disconnected:
        if (state.status == CreateRoomFlowStatus.ready) {
          // Participant left - host returns to listening for new participants
          developer.log(
            'CreateRoomFlow: Participant disconnected, returning to listening',
            name: 'SoundMesh.CreateRoomFlow',
          );
          state = state.copyWith(
            status: CreateRoomFlowStatus.listening,
            sessionId: null,
            roomId: null,
          );
        } else if (state.status != CreateRoomFlowStatus.idle &&
            state.status != CreateRoomFlowStatus.failed) {
          state = state.copyWith(
            status: CreateRoomFlowStatus.failed,
            errorMessage: 'Connection lost',
          );
        }
        break;
      default:
        break;
    }
  }

  void _handleProtocolMessage(ProtocolMessage message) {
    // Host sends WELCOME, participant receives it
    // We don't need to do anything special here for the host
  }

  void setRoomName(String name) {
    state = state.copyWith(roomName: name);
  }

  Future<void> createRoom({WidgetRef? ref}) async {
    developer.log(
      'CreateRoomFlow: createRoom() called | roomName: "${state.roomName}" | currentStatus: ${state.status.name}',
      name: 'SoundMesh.CreateRoomFlow',
    );
    
    if (_createRoomInProgress ||
        state.status == CreateRoomFlowStatus.creating ||
        state.status == CreateRoomFlowStatus.hosting) {
      developer.log(
        'CreateRoomFlow: createRoom() early return - inProgress: $_createRoomInProgress, status: ${state.status.name}',
        name: 'SoundMesh.CreateRoomFlow',
      );
      return;
    }

    _createRoomInProgress = true;
    try {
      if (state.roomName.trim().isEmpty) {
        developer.log(
          'CreateRoomFlow: Validation failed - empty room name',
          name: 'SoundMesh.CreateRoomFlow',
        );
        state = state.copyWith(
          errorMessage: 'Please enter a room name',
          status: CreateRoomFlowStatus.idle,
        );
        return;
      }

      developer.log(
        'CreateRoomFlow: Setting status to creating',
        name: 'SoundMesh.CreateRoomFlow',
      );
      state = state.copyWith(status: CreateRoomFlowStatus.creating);

      final ip = await _networkRepository.getLocalIpAddress();
      developer.log(
        'CreateRoomFlow: Got local IP: $ip',
        name: 'SoundMesh.CreateRoomFlow',
      );
      
      if (state.status != CreateRoomFlowStatus.creating) {
        developer.log(
          'CreateRoomFlow: Status changed during IP fetch, aborting',
          name: 'SoundMesh.CreateRoomFlow',
        );
        return;
      }

      // Quick fix: Generate join code immediately when entering hosting status
      // This eliminates the race condition where discoverable is emitted before code exists
      final joinCode = generateRoomCode();
      developer.log(
        'CreateRoomFlow: Generated join code: $joinCode | Setting status to hosting',
        name: 'SoundMesh.CreateRoomFlow',
      );

      // The announcement must advertise the room's actual identifier, not a
      // separate discovery-time value: the repository uses this roomId for the
      // WELCOME handshake so participants can verify the room they joined.
      final roomId = generateUuidV4();
      final expiresAt = DateTime.now().add(kJoinCodeLifetime);

      state = state.copyWith(
        localIpAddress: ip,
        status: CreateRoomFlowStatus.hosting,
        joinCode: joinCode,
        roomId: roomId,
      );

      developer.log(
        'CreateRoomFlow: Starting UDP broadcast for code: $joinCode (roomId: $roomId)',
        name: 'SoundMesh.CreateRoomFlow',
      );
      final broadcastSuccess = await _discoveryManager.hostService.startBroadcast(
        code: joinCode,
        roomId: roomId,
        port: state.port ?? 8765,
        expiresAt: expiresAt,
      );
      developer.log(
        'CreateRoomFlow: UDP broadcast started: $broadcastSuccess',
        name: 'SoundMesh.CreateRoomFlow',
      );

      developer.log(
        'CreateRoomFlow: Starting hosting on port ${state.port ?? 8765}',
        name: 'SoundMesh.CreateRoomFlow',
      );
      final hostingSuccess = await _networkRepository.startHosting(
        port: state.port ?? 8765,
        roomId: roomId,
      );
      developer.log(
        'CreateRoomFlow: startHosting returned: $hostingSuccess',
        name: 'SoundMesh.CreateRoomFlow',
      );

      // Explicitly sync role after startHosting to ensure RoomLifecycleNotifier
      // has the correct role (host) immediately, avoiding race condition where
      // initial sync reads default role before NetworkRepository is updated.
      if (hostingSuccess && ref != null) {
        ref.read(roomLifecycleProvider.notifier).syncRoleAndParticipantState();
      }
      
      developer.log(
        'CreateRoomFlow: startHosting completed',
        name: 'SoundMesh.CreateRoomFlow',
      );
      // Reset host-ended flag from previous room so new room starts clean
      if (hostingSuccess && ref != null) {
        ref.read(roomLifecycleProvider.notifier).resetForNewRoom();
      }
    } finally {
      _createRoomInProgress = false;
    }
  }

  void reset() {
    _networkRepository.disconnect();
    _createRoomInProgress = false;
    state = const CreateRoomFlowState();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _protocolMessageSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    super.dispose();
  }
}

final createRoomFlowProvider =
    StateNotifierProvider<CreateRoomFlowNotifier, CreateRoomFlowState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  final discoveryManager = ref.watch(discoveryManagerProvider);
  return CreateRoomFlowNotifier(networkRepo, discoveryManager);
});