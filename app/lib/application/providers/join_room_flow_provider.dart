import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/network_repository.dart';

enum JoinRoomFlowStatus {
  idle,
  connecting,
  connected,
  failed,
}

class JoinRoomFlowState {
  final JoinRoomFlowStatus status;
  final String hostIpAddress;
  final int hostPort;
  final String? errorMessage;
  final NetworkConnectionState connectionState;

  const JoinRoomFlowState({
    this.status = JoinRoomFlowStatus.idle,
    this.hostIpAddress = '',
    this.hostPort = 8765,
    this.errorMessage,
    this.connectionState = NetworkConnectionState.disconnected,
  });

  JoinRoomFlowState copyWith({
    JoinRoomFlowStatus? status,
    String? hostIpAddress,
    int? hostPort,
    String? errorMessage,
    NetworkConnectionState? connectionState,
  }) {
    return JoinRoomFlowState(
      status: status ?? this.status,
      hostIpAddress: hostIpAddress ?? this.hostIpAddress,
      hostPort: hostPort ?? this.hostPort,
      errorMessage: errorMessage,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}

class JoinRoomFlowNotifier extends StateNotifier<JoinRoomFlowState> {
  final NetworkRepository _networkRepository;
  StreamSubscription? _stateSubscription;

  JoinRoomFlowNotifier(this._networkRepository)
      : super(const JoinRoomFlowState()) {
    _stateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == NetworkConnectionState.connected &&
          state.status == JoinRoomFlowStatus.connecting) {
        state = state.copyWith(status: JoinRoomFlowStatus.connected);
      } else if (connState == NetworkConnectionState.failed &&
          state.status == JoinRoomFlowStatus.connecting) {
        state = state.copyWith(
          status: JoinRoomFlowStatus.failed,
          errorMessage: 'Connection refused or host unreachable',
        );
      }
    });
  }

  void setHostIpAddress(String ip) {
    state = state.copyWith(hostIpAddress: ip);
  }

  void setHostPort(int port) {
    state = state.copyWith(hostPort: port);
  }

  Future<void> joinRoom() async {
    if (state.hostIpAddress.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter the host IP address',
        status: JoinRoomFlowStatus.idle,
      );
      return;
    }

    state = state.copyWith(status: JoinRoomFlowStatus.connecting);

    final success = await _networkRepository.connectToHost(
      state.hostIpAddress,
      port: state.hostPort,
    );

    if (!success) {
      state = state.copyWith(
        status: JoinRoomFlowStatus.failed,
        errorMessage: 'Failed to initiate connection',
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
    super.dispose();
  }
}

final joinRoomFlowProvider =
    StateNotifierProvider<JoinRoomFlowNotifier, JoinRoomFlowState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  return JoinRoomFlowNotifier(networkRepo);
});
