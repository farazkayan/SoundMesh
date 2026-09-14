import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/network_repository.dart';
import '../protocol.dart';

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
  final String? sessionId;
  final String? roomId;

  const CreateRoomFlowState({
    this.status = CreateRoomFlowStatus.idle,
    this.roomName = '',
    this.localIpAddress,
    this.port = 8765,
    this.errorMessage,
    this.connectionState = NetworkConnectionState.disconnected,
    this.sessionId,
    this.roomId,
  });

  CreateRoomFlowState copyWith({
    CreateRoomFlowStatus? status,
    String? roomName,
    String? localIpAddress,
    int? port,
    String? errorMessage,
    NetworkConnectionState? connectionState,
    String? sessionId,
    String? roomId,
  }) {
    return CreateRoomFlowState(
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      localIpAddress: localIpAddress ?? this.localIpAddress,
      port: port ?? this.port,
      errorMessage: errorMessage,
      connectionState: connectionState ?? this.connectionState,
      sessionId: sessionId ?? this.sessionId,
      roomId: roomId ?? this.roomId,
    );
  }
}

class CreateRoomFlowNotifier extends StateNotifier<CreateRoomFlowState> {
  final NetworkRepository _networkRepository;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _protocolMessageSubscription;
  StreamSubscription? _connectionErrorSubscription;
  bool _createRoomInProgress = false;

  CreateRoomFlowNotifier(this._networkRepository)
    : super(const CreateRoomFlowState()) {
    _stateSubscription = _networkRepository.connectionStateStream.listen((
      connState,
    ) {
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

  void _handleProtocolMessage(ProtocolMessage message) {
    // Host sends WELCOME, participant receives it
    // We don't need to do anything special here for the host
  }

  void setRoomName(String name) {
    state = state.copyWith(roomName: name);
  }

  Future<void> createRoom() async {
    if (_createRoomInProgress ||
        state.status == CreateRoomFlowStatus.creating ||
        state.status == CreateRoomFlowStatus.hosting) {
      return;
    }

    _createRoomInProgress = true;
    try {
      if (state.roomName.trim().isEmpty) {
        state = state.copyWith(
          errorMessage: 'Please enter a room name',
          status: CreateRoomFlowStatus.idle,
        );
        return;
      }

      state = state.copyWith(status: CreateRoomFlowStatus.creating);

      final ip = await _networkRepository.getLocalIpAddress();
      if (state.status != CreateRoomFlowStatus.creating) {
        return;
      }

      state = state.copyWith(
        localIpAddress: ip,
        status: CreateRoomFlowStatus.hosting,
      );

      await _networkRepository.startHosting(port: state.port ?? 8765);
    } finally {
      _createRoomInProgress = false;
    }
  }

  Future<void> startHosting() async {
    if (state.status != CreateRoomFlowStatus.ready) {
      state = state.copyWith(status: CreateRoomFlowStatus.hosting);
      await _networkRepository.startHosting(port: state.port ?? 8765);
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
  return CreateRoomFlowNotifier(networkRepo);
});