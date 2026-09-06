import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/src/network_messages.g.dart';

enum NetworkConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
}

class NetworkRepository {
  final NetworkHostPlatform _platform;
  final StreamController<NetworkConnectionState> _stateController =
      StreamController<NetworkConnectionState>.broadcast();
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  NetworkConnectionState _currentState = NetworkConnectionState.disconnected;
  late final _NetworkFlutterApi _flutterApi;

  NetworkRepository() : _platform = NetworkHostPlatform() {
    _flutterApi = _NetworkFlutterApi(
      onMessageCallback: (message) {
        _messageController.add(message);
      },
      onStateCallback: (state) {
        _currentState = _parseState(state);
        _stateController.add(_currentState);
      },
    );
    NetworkFlutterApi.setUp(_flutterApi);
  }

  NetworkConnectionState _parseState(String state) {
    switch (state) {
      case 'connecting':
        return NetworkConnectionState.connecting;
      case 'connected':
        return NetworkConnectionState.connected;
      case 'failed':
        return NetworkConnectionState.failed;
      default:
        return NetworkConnectionState.disconnected;
    }
  }

  Stream<NetworkConnectionState> get connectionStateStream =>
      _stateController.stream;

  Stream<String> get messageStream => _messageController.stream;

  NetworkConnectionState get currentState => _currentState;

  Future<bool> startHosting({int port = 8765}) async {
    try {
      return await _platform.startHosting(port);
    } catch (e) {
      return false;
    }
  }

  Future<bool> connectToHost(String ipAddress, {int port = 8765}) async {
    try {
      return await _platform.connectToHost(ipAddress, port);
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendMessage(String message) async {
    try {
      return await _platform.sendMessage(message);
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _platform.disconnect();
    } catch (e) {
      // ignore
    }
  }

  Future<String> getLocalIpAddress() async {
    try {
      return await _platform.getLocalIpAddress();
    } catch (e) {
      return '127.0.0.1';
    }
  }

  void dispose() {
    _stateController.close();
    _messageController.close();
  }
}

final networkRepositoryProvider = Provider<NetworkRepository>((ref) {
  final repo = NetworkRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

class _NetworkFlutterApi extends NetworkFlutterApi {
  final void Function(String) onMessageCallback;
  final void Function(String) onStateCallback;

  _NetworkFlutterApi({
    required this.onMessageCallback,
    required this.onStateCallback,
  });

  @override
  void onMessageReceived(String message) {
    onMessageCallback(message);
  }

  @override
  void onConnectionStateChanged(String state) {
    onStateCallback(state);
  }
}
