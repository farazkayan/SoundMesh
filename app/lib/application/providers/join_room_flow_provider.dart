import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/network_repository.dart';
import '../protocol.dart';
import '../room/room_lifecycle.dart';
enum JoinRoomFlowStatus {
  idle,
  connecting,
  handshaking,
  ready,
  failed,
}

class JoinRoomFlowState {
  final JoinRoomFlowStatus status;
  final String hostIpAddress;
  final int hostPort;
  final String? errorMessage;
  final NetworkConnectionState connectionState;
  final RoomLifecycleState roomLifecycleState;
  final String? sessionId;
  final String? roomId;
  final int? hostProtocolVersion;
  final String? joinCode;

  const JoinRoomFlowState({
    this.status = JoinRoomFlowStatus.idle,
    this.hostIpAddress = '',
    this.hostPort = 8765,
    this.errorMessage,
    this.connectionState = NetworkConnectionState.disconnected,
    this.roomLifecycleState = RoomLifecycleState.created,
    this.sessionId,
    this.roomId,
    this.hostProtocolVersion,
    this.joinCode,
  });

  JoinRoomFlowState copyWith({
    JoinRoomFlowStatus? status,
    String? hostIpAddress,
    int? hostPort,
    String? errorMessage,
    NetworkConnectionState? connectionState,
    RoomLifecycleState? roomLifecycleState,
    String? sessionId,
    String? roomId,
    int? hostProtocolVersion,
    String? joinCode,
  }) {
    return JoinRoomFlowState(
      status: status ?? this.status,
      hostIpAddress: hostIpAddress ?? this.hostIpAddress,
      hostPort: hostPort ?? this.hostPort,
      errorMessage: errorMessage,
      connectionState: connectionState ?? this.connectionState,
      roomLifecycleState: roomLifecycleState ?? this.roomLifecycleState,
      sessionId: sessionId ?? this.sessionId,
      roomId: roomId ?? this.roomId,
      hostProtocolVersion: hostProtocolVersion ?? this.hostProtocolVersion,
      joinCode: joinCode ?? this.joinCode,
    );
  }
}

class JoinRoomFlowNotifier extends StateNotifier<JoinRoomFlowState> {
  final NetworkRepository _networkRepository;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _protocolMessageSubscription;
  StreamSubscription? _connectionErrorSubscription;
  StreamSubscription? _roomLifecycleSubscription;

  JoinRoomFlowNotifier(this._networkRepository)
      : super(const JoinRoomFlowState()) {
    _stateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      debugPrint('[UILifecycle] JoinRoomFlow: connectionState change -> $connState (current status: ${state.status})');
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
        debugPrint('[UILifecycle] JoinRoomFlow: connectionError -> $error');
        _handleConnectionError(error);
      },
    );

    _roomLifecycleSubscription = _networkRepository.roomLifecycleStateStream.listen((
      lifecycleState,
    ) {
      debugPrint('[UILifecycle] JoinRoomFlow: roomLifecycleState change -> $lifecycleState (current status: ${state.status})');
      state = state.copyWith(roomLifecycleState: lifecycleState);
      _handleRoomLifecycleStateChange(lifecycleState);
    });
  }

  void _handleConnectionError(ConnectionError error) {
    String userMessage;
    switch (error.errorCode) {
      case 'CONNECTION_REFUSED':
        userMessage = 'Could not connect to host — connection refused. Check the IP address and that the host is running.';
        break;
      case 'CONNECTION_TIMEOUT':
        userMessage = 'Connection timed out. Check the IP address and that both devices are on the same network.';
        break;
      case 'UNKNOWN_HOST':
        userMessage = 'Could not resolve host address. Check the IP address.';
        break;
      case 'SOCKET_ERROR':
        userMessage = 'Network error: ${error.errorMessage}';
        break;
      case 'CONNECTION_FAILED':
      default:
        userMessage = 'Could not connect to host — ${error.errorMessage}. Check the IP address and that both devices are on the same network.';
        break;
    }
    
    if (state.status == JoinRoomFlowStatus.connecting || state.status == JoinRoomFlowStatus.handshaking) {
      state = state.copyWith(
        status: JoinRoomFlowStatus.failed,
        errorMessage: userMessage,
      );
    }
  }

  void _handleConnectionStateChange(NetworkConnectionState connState) {
    switch (connState) {
      case NetworkConnectionState.connected:
        if (state.status == JoinRoomFlowStatus.connecting) {
          state = state.copyWith(status: JoinRoomFlowStatus.handshaking);
        }
        break;
      case NetworkConnectionState.ready:
        if (state.status == JoinRoomFlowStatus.handshaking) {
          state = state.copyWith(
            status: JoinRoomFlowStatus.ready,
            sessionId: _networkRepository.sessionId,
            roomId: _networkRepository.roomId,
          );
        }
        break;
      case NetworkConnectionState.failed:
        // Only set generic "Handshake failed" if we don't already have a specific connection error
        if (state.status == JoinRoomFlowStatus.connecting ||
            state.status == JoinRoomFlowStatus.handshaking) {
          if (state.errorMessage == null || state.errorMessage == 'Failed to initiate connection') {
            state = state.copyWith(
              status: JoinRoomFlowStatus.failed,
              errorMessage: 'Handshake failed',
            );
          }
        }
        break;
      case NetworkConnectionState.disconnected:
        if (state.status != JoinRoomFlowStatus.idle &&
            state.status != JoinRoomFlowStatus.failed) {
          state = state.copyWith(
            status: JoinRoomFlowStatus.failed,
            errorMessage: 'Connection lost',
          );
        }
        break;
      default:
        break;
    }
  }

  void _handleRoomLifecycleStateChange(RoomLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case RoomLifecycleState.created:
        if (state.status == JoinRoomFlowStatus.idle) {
          state = state.copyWith(status: JoinRoomFlowStatus.connecting);
        }
        break;
      case RoomLifecycleState.joining:
        if (state.status == JoinRoomFlowStatus.connecting ||
            state.status == JoinRoomFlowStatus.handshaking) {
          state = state.copyWith(status: JoinRoomFlowStatus.handshaking);
        }
        break;
      case RoomLifecycleState.ready:
        if (state.status == JoinRoomFlowStatus.handshaking) {
          state = state.copyWith(
            status: JoinRoomFlowStatus.ready,
            sessionId: _networkRepository.sessionId,
            roomId: _networkRepository.roomId,
          );
        }
        break;
      case RoomLifecycleState.closed:
        if (state.status != JoinRoomFlowStatus.idle &&
            state.status != JoinRoomFlowStatus.failed) {
          state = state.copyWith(
            status: JoinRoomFlowStatus.failed,
            errorMessage: _networkRepository.roomClosedReason ?? 'You left the room',
          );
        }
        break;
      case RoomLifecycleState.discoverable:
        // Not applicable for participant
        break;
    }
  }

  void _handleProtocolMessage(ProtocolMessage message) {
    final messageType = ProtocolMessageTypeX.fromWireValue(message.messageType);
    if (messageType == ProtocolMessageType.versionRejected) {
      final hostVersion = message.payload?['hostVersion'] as int?;
      final participantVersion = message.payload?['participantVersion'] as int?;
      state = state.copyWith(
        status: JoinRoomFlowStatus.failed,
        errorMessage: 'Protocol version mismatch: host v${hostVersion ?? '?'} vs this device v${participantVersion ?? currentProtocolVersion}',
        hostProtocolVersion: hostVersion,
      );
      _networkRepository.disconnect();
    } else if (messageType == ProtocolMessageType.welcome) {
      // Handled by connection state change to ready
    } else if (messageType == ProtocolMessageType.joinRejected) {
      final reasonStr = message.payload?['reason'] as String?;
      state = state.copyWith(
        status: JoinRoomFlowStatus.failed,
        errorMessage: _joinRejectReasonToMessage(reasonStr),
      );
      _networkRepository.disconnect();
    }
  }

  String _joinRejectReasonToMessage(String? reason) {
    switch (reason) {
      case 'ROOM_FULL':
        return 'Room full';
      case 'VERSION_MISMATCH':
        return 'Protocol version mismatch';
      case 'CLOSED':
        return 'Room is closed';
      case 'INTERNAL_ERROR':
        return 'Internal error';
      default:
        return 'Join rejected: ${reason ?? 'unknown reason'}';
    }
  }

  void setHostIpAddress(String ip) {
    state = state.copyWith(hostIpAddress: ip);
  }

  void setHostPort(int port) {
    state = state.copyWith(hostPort: port);
  }

  void setJoinCode(String code) {
    state = state.copyWith(joinCode: code);
  }

  Future<void> joinRoom() async {
    developer.log(
      '[JOIN_TRACE] JoinRoomFlowNotifier: joinRoom ENTERED',
      name: 'SoundMesh.JoinRoomFlow',
    );
    developer.log(
      '[JOIN_TRACE] JoinRoomFlowNotifier: joinRoom called with hostIpAddress=${state.hostIpAddress}, hostPort=${state.hostPort}',
      name: 'SoundMesh.JoinRoomFlow',
    );
    if (state.hostIpAddress.trim().isEmpty) {
      developer.log(
        '[JOIN_TRACE] JoinRoomFlowNotifier: hostIpAddress is empty - returning error',
        name: 'SoundMesh.JoinRoomFlow',
      );
      state = state.copyWith(
        errorMessage: 'Please enter the host IP address',
        status: JoinRoomFlowStatus.idle,
      );
      return;
    }

    if (state.hostPort < 1 || state.hostPort > 65535) {
      developer.log(
        '[JOIN_TRACE] JoinRoomFlowNotifier: hostPort invalid - returning error',
        name: 'SoundMesh.JoinRoomFlow',
      );
      state = state.copyWith(
        errorMessage: 'Port must be between 1 and 65535',
        status: JoinRoomFlowStatus.idle,
      );
      return;
    }

    developer.log(
      '[JOIN_TRACE] JoinRoomFlowNotifier: Setting status to connecting',
      name: 'SoundMesh.JoinRoomFlow',
    );
    state = state.copyWith(status: JoinRoomFlowStatus.connecting);

    developer.log(
      '[JOIN_TRACE] JoinRoomFlowNotifier: Calling _networkRepository.connectToHost',
      name: 'SoundMesh.JoinRoomFlow',
    );

    final success = await _networkRepository.connectToHost(
      state.hostIpAddress,
      port: state.hostPort,
    );

    developer.log(
      '[JOIN_TRACE] JoinRoomFlowNotifier: connectToHost returned: $success',
      name: 'SoundMesh.JoinRoomFlow',
    );

    if (!success) {
      developer.log(
        '[JOIN_TRACE] JoinRoomFlowNotifier: connectToHost failed - setting failed status',
        name: 'SoundMesh.JoinRoomFlow',
      );
      state = state.copyWith(
        status: JoinRoomFlowStatus.failed,
        errorMessage: 'Failed to initiate connection',
      );
    } else {
      developer.log(
        '[JOIN_TRACE] JoinRoomFlowNotifier: connectToHost succeeded',
        name: 'SoundMesh.JoinRoomFlow',
      );
    }
  }

  void reset() {
    _networkRepository.disconnect();
    state = const JoinRoomFlowState();
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

final joinRoomFlowProvider =
    StateNotifierProvider<JoinRoomFlowNotifier, JoinRoomFlowState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  return JoinRoomFlowNotifier(networkRepo);
});