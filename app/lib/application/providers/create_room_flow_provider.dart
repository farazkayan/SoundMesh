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
  StreamSubscription? _roomLifecycleSubscription;
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

    _roomLifecycleSubscription = _networkRepository.roomLifecycleStateStream.listen((
      lifecycleState,
    ) {
      debugPrint('[UILifecycle] CreateRoomFlow: roomLifecycleState change -> $lifecycleState (current status: ${state.status})');
      state = state.copyWith(roomLifecycleState: lifecycleState);
      _handleRoomLifecycleStateChange(lifecycleState);
    });
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
        if (state.status != CreateRoomFlowStatus.idle &&
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

  void _handleRoomLifecycleStateChange(RoomLifecycleState lifecycleState) {
    developer.log(
      'CreateRoomFlow: Received lifecycle state: ${lifecycleState.name} | '
      'Current status: ${state.status.name} | joinCode: ${state.joinCode ?? "null"}',
      name: 'SoundMesh.CreateRoomFlow',
    );
    
    switch (lifecycleState) {
      case RoomLifecycleState.created:
        if (state.status == CreateRoomFlowStatus.idle) {
          developer.log(
            'CreateRoomFlow: Transitioning to creating',
            name: 'SoundMesh.CreateRoomFlow',
          );
          state = state.copyWith(status: CreateRoomFlowStatus.creating);
        }
        break;
      case RoomLifecycleState.discoverable:
        if (state.status == CreateRoomFlowStatus.creating ||
            state.status == CreateRoomFlowStatus.hosting) {
          // Join code is now generated in createRoom() to avoid race condition
          // Just update status to listening
          developer.log(
            'CreateRoomFlow: Room discoverable, setting status to listening (joinCode already set: ${state.joinCode})',
            name: 'SoundMesh.CreateRoomFlow',
          );
          state = state.copyWith(
            status: CreateRoomFlowStatus.listening,
          );
        } else {
          developer.log(
            'CreateRoomFlow: SKIPPED status update - status not creating/hosting (current: ${state.status.name})',
            name: 'SoundMesh.CreateRoomFlow',
          );
        }
        break;
      case RoomLifecycleState.joining:
        if (state.status == CreateRoomFlowStatus.listening) {
          developer.log(
            'CreateRoomFlow: Transitioning to handshaking',
            name: 'SoundMesh.CreateRoomFlow',
          );
          state = state.copyWith(status: CreateRoomFlowStatus.handshaking);
        }
        break;
      case RoomLifecycleState.ready:
        if (state.status == CreateRoomFlowStatus.handshaking) {
          developer.log(
            'CreateRoomFlow: Room ready, setting status to ready',
            name: 'SoundMesh.CreateRoomFlow',
          );
          state = state.copyWith(
            status: CreateRoomFlowStatus.ready,
            sessionId: _networkRepository.sessionId,
            roomId: _networkRepository.roomId,
          );
        }
        break;
      case RoomLifecycleState.closed:
        if (state.status != CreateRoomFlowStatus.idle &&
            state.status != CreateRoomFlowStatus.failed) {
          developer.log(
            'CreateRoomFlow: Room closed, setting failed',
            name: 'SoundMesh.CreateRoomFlow',
          );
          state = state.copyWith(
            status: CreateRoomFlowStatus.failed,
            errorMessage: _networkRepository.roomClosedReason ?? 'Room ended',
          );
        }
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

Future<void> createRoom() async {
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

      // Generate roomId at creation time for QR code payload
      final roomId = generateUuidV4();
      developer.log(
        'CreateRoomFlow: Generated roomId: $roomId',
        name: 'SoundMesh.CreateRoomFlow',
      );

      // Quick fix: Generate join code immediately when entering hosting status
      // This eliminates the race condition where discoverable is emitted before code exists
      final joinCode = generateRoomCode();
      developer.log(
        'CreateRoomFlow: Generated join code: $joinCode | Setting status to hosting',
        name: 'SoundMesh.CreateRoomFlow',
      );

      state = state.copyWith(
        localIpAddress: ip,
        status: CreateRoomFlowStatus.hosting,
        joinCode: joinCode,
        roomId: roomId,
      );

      developer.log(
        'CreateRoomFlow: Starting UDP broadcast for code: $joinCode',
        name: 'SoundMesh.CreateRoomFlow',
      );
      final broadcastSuccess = await _discoveryManager.hostService.startBroadcast(
        code: joinCode,
        roomId: roomId,
        port: state.port ?? 8765,
      );
      developer.log(
        'CreateRoomFlow: UDP broadcast started: $broadcastSuccess',
        name: 'SoundMesh.CreateRoomFlow',
      );

      developer.log(
        'CreateRoomFlow: Starting hosting on port ${state.port ?? 8765}',
        name: 'SoundMesh.CreateRoomFlow',
      );
      final hostingSuccess = await _networkRepository.startHosting(port: state.port ?? 8765);
      developer.log(
        'CreateRoomFlow: startHosting returned: $hostingSuccess',
        name: 'SoundMesh.CreateRoomFlow',
      );

      developer.log(
        'CreateRoomFlow: startHosting completed',
        name: 'SoundMesh.CreateRoomFlow',
      );
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
    _roomLifecycleSubscription?.cancel();
    super.dispose();
  }
}

final createRoomFlowProvider =
    StateNotifierProvider<CreateRoomFlowNotifier, CreateRoomFlowState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  final discoveryManager = ref.watch(discoveryManagerProvider);
  return CreateRoomFlowNotifier(networkRepo, discoveryManager);
});