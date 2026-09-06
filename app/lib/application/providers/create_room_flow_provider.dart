import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/network_repository.dart';

enum CreateRoomFlowStatus {
  idle,
  creating,
  hosting,
  hosted,
  failed,
}

class CreateRoomFlowState {
  final CreateRoomFlowStatus status;
  final String roomName;
  final String? localIpAddress;
  final int? port;
  final String? errorMessage;
  final NetworkConnectionState connectionState;

  const CreateRoomFlowState({
    this.status = CreateRoomFlowStatus.idle,
    this.roomName = '',
    this.localIpAddress,
    this.port = 8765,
    this.errorMessage,
    this.connectionState = NetworkConnectionState.disconnected,
  });

  CreateRoomFlowState copyWith({
    CreateRoomFlowStatus? status,
    String? roomName,
    String? localIpAddress,
    int? port,
    String? errorMessage,
    NetworkConnectionState? connectionState,
  }) {
    return CreateRoomFlowState(
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      localIpAddress: localIpAddress ?? this.localIpAddress,
      port: port ?? this.port,
      errorMessage: errorMessage,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}

class CreateRoomFlowNotifier extends StateNotifier<CreateRoomFlowState> {
  final NetworkRepository _networkRepository;
  StreamSubscription? _stateSubscription;

  CreateRoomFlowNotifier(this._networkRepository)
      : super(const CreateRoomFlowState()) {
    _stateSubscription = _networkRepository.connectionStateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == NetworkConnectionState.connected &&
          state.status == CreateRoomFlowStatus.hosting) {
        state = state.copyWith(status: CreateRoomFlowStatus.hosted);
      } else if (connState == NetworkConnectionState.failed &&
          state.status == CreateRoomFlowStatus.hosting) {
        state = state.copyWith(
          status: CreateRoomFlowStatus.failed,
          errorMessage: 'Failed to start hosting',
        );
      }
    });
  }

  void setRoomName(String name) {
    state = state.copyWith(roomName: name);
  }

  Future<void> createRoom() async {
    if (state.roomName.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please enter a room name',
        status: CreateRoomFlowStatus.idle,
      );
      return;
    }

    state = state.copyWith(status: CreateRoomFlowStatus.creating);

    final ip = await _networkRepository.getLocalIpAddress();
    state = state.copyWith(
      localIpAddress: ip,
      status: CreateRoomFlowStatus.hosting,
    );

    await _networkRepository.startHosting(port: state.port ?? 8765);
  }

  Future<void> startHosting() async {
    if (state.status != CreateRoomFlowStatus.hosted) {
      state = state.copyWith(status: CreateRoomFlowStatus.hosting);
      await _networkRepository.startHosting(port: state.port ?? 8765);
    }
  }

  void reset() {
    _networkRepository.disconnect();
    state = const CreateRoomFlowState();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}

final createRoomFlowProvider =
    StateNotifierProvider<CreateRoomFlowNotifier, CreateRoomFlowState>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  return CreateRoomFlowNotifier(networkRepo);
});
