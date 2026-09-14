import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';
import '../protocol.dart';

const Duration _handshakeTimeout = Duration(seconds: 10);

String _generateParticipantId() => generateUuidV4();

class _MockNetworkHostPlatform extends NetworkHostPlatform {
  @override
  Future<bool> startHosting(int port) async => true;

  @override
  Future<bool> connectToHost(String ipAddress, int port) async => true;

  @override
  Future<bool> sendMessage(String message) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> getLocalIpAddress() async => '127.0.0.1';
}

class ConnectionError {
  final String errorCode;
  final String errorMessage;

  ConnectionError(this.errorCode, this.errorMessage);

  @override
  String toString() => 'ConnectionError(code: $errorCode, message: $errorMessage)';
}

enum NetworkConnectionState {
  disconnected,
  connecting,
  connected,
  listening,
  handshaking,
  ready,
  failed,
}

class NetworkRepository {
  final NetworkHostPlatform _platform;
  final StreamController<NetworkConnectionState> _stateController =
      StreamController<NetworkConnectionState>.broadcast();
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final StreamController<ProtocolMessage> _protocolMessageController =
      StreamController<ProtocolMessage>.broadcast();
  final StreamController<ConnectionError> _connectionErrorController =
      StreamController<ConnectionError>.broadcast();

  NetworkConnectionState _currentState = NetworkConnectionState.disconnected;
  late final _NetworkFlutterApi _flutterApi;

  String _participantId = _generateParticipantId();
  String? _sessionId;
  String? _roomId;
  int _generation = 0;
  bool _isHost = false;
  bool _handshakeInitiated = false;
  Timer? _handshakeTimer;

  NetworkRepository() : _platform = NetworkHostPlatform() {
    _init(handshakeTimeout: _handshakeTimeout);
  }

  // Test constructor with custom timeout and mock platform
  NetworkRepository.test(Duration handshakeTimeout, {NetworkHostPlatform? platform})
      : _platform = platform ?? _MockNetworkHostPlatform() {
    _init(handshakeTimeout: handshakeTimeout);
  }

  void _init({required Duration handshakeTimeout}) {
    _flutterApi = _NetworkFlutterApi(
      onMessageCallback: (message) {
        _handleRawMessage(message);
      },
      onStateCallback: (state) {
        // For host, "connected" from native means ServerSocket is listening
        // For participant, "connected" means TCP connection established
        if (_isHost && state == 'connected') {
          _currentState = NetworkConnectionState.listening;
          _stateController.add(_currentState);
          _onTcpConnected(); // This will handle host listening logic
        } else {
          _currentState = _parseState(state);
          _stateController.add(_currentState);

          if (_currentState == NetworkConnectionState.connected) {
            _onTcpConnected();
          }
        }
      },
      onErrorCallback: (errorCode, errorMessage) {
        debugPrint('[Connection] Error from native: code=$errorCode, message=$errorMessage');
        _connectionErrorController.add(ConnectionError(errorCode, errorMessage));
        
        // Also transition to failed state if we're in connecting state
        if (_currentState == NetworkConnectionState.connecting) {
          _transitionTo(NetworkConnectionState.failed, reason: 'Connection error: $errorCode - $errorMessage');
        }
      },
    );
    NetworkFlutterApi.setUp(_flutterApi);
  }

  String get participantId => _participantId;
  String? get sessionId => _sessionId;
  String? get roomId => _roomId;
  int get generation => _generation;
  bool get isHost => _isHost;

  Stream<NetworkConnectionState> get connectionStateStream =>
      _stateController.stream;

  Stream<String> get messageStream => _messageController.stream;

  Stream<ProtocolMessage> get protocolMessageStream =>
      _protocolMessageController.stream;

  Stream<ConnectionError> get connectionErrorStream =>
      _connectionErrorController.stream;

  NetworkConnectionState get currentState => _currentState;

  Future<bool> startHosting({int port = 8765}) async {
    _isHost = true;
    _handshakeInitiated = false;
    try {
      return await _platform.startHosting(port);
    } catch (e) {
      return false;
    }
  }

  Future<bool> connectToHost(String ipAddress, {int port = 8765}) async {
    _isHost = false;
    _handshakeInitiated = false;
    debugPrint('[Connection] Dart: Initiating TCP connect to $ipAddress:$port');
    try {
      return await _platform.connectToHost(ipAddress, port);
    } catch (e) {
      debugPrint('[Connection] Dart: TCP connect threw exception: $e');
      return false;
    }
  }

  Future<bool> sendMessage(String message) async {
    try {
      final chatMessage = ProtocolMessage.chat(
        senderId: _participantId,
        text: message,
        sessionId: _sessionId,
        generation: _generation,
      );
      return await sendProtocolMessage(chatMessage);
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendProtocolMessage(ProtocolMessage message) async {
    return sendMessage(message.toJsonString());
  }

  Future<void> disconnect() async {
    try {
      await _platform.disconnect();
    } catch (e) {
      // ignore
    }
    _resetHandshakeState();
  }

  Future<String> getLocalIpAddress() async {
    try {
      return await _platform.getLocalIpAddress();
    } catch (e) {
      return '127.0.0.1';
    }
  }

  void _resetHandshakeState() {
    _cancelHandshakeTimer();
    _sessionId = null;
    _roomId = null;
    _generation = 0;
    _handshakeInitiated = false;
  }

  void _onTcpConnected() {
    _cancelHandshakeTimer();
    if (_isHost) {
      debugPrint('[Handshake] Host: TCP listener ready, entering listening state');
      _transitionTo(NetworkConnectionState.listening);
      // Do NOT start handshake timer here - wait for participant to connect (HELLO received)
    } else {
      debugPrint('[Handshake] Participant: TCP connected, sending HELLO');
      _sendHello();
      _transitionTo(NetworkConnectionState.handshaking);
      _startHandshakeTimer();
    }
  }

  // Test helper to manually trigger TCP connected state
  void triggerTcpConnectedForTest() {
    _onTcpConnected();
  }

  void _sendHello() {
    if (_handshakeInitiated) return;
    _handshakeInitiated = true;

    final hello = ProtocolMessage.hello(
      protocolVersion: CURRENT_PROTOCOL_VERSION,
      participantId: _participantId,
      generation: _generation,
    );
    debugPrint('[Handshake] Participant: Sending HELLO: ${hello.toJsonString()}');
    sendProtocolMessage(hello);
  }

  void handleRawMessageForTest(String rawMessage) {
    _handleRawMessage(rawMessage);
  }

  void _handleRawMessage(String rawMessage) {
    // Only emit parsed CHAT messages to the user-visible message stream
    // Protocol messages (HELLO, WELCOME, etc.) are handled silently
    debugPrint('[Handshake] Received raw message: $rawMessage');

    try {
      final protocolMessage = ProtocolMessage.fromJsonString(rawMessage);
      final messageType = ProtocolMessageTypeX.fromWireValue(protocolMessage.messageType);
      debugPrint('[Handshake] Parsed message type: $messageType');
      _handleProtocolMessage(protocolMessage);
    } on ProtocolMessageDecodeError catch (e) {
      _handleDecodeError(e, rawMessage);
    } catch (e) {
      _handleDecodeError(ProtocolMessageDecodeError('Unexpected error: $e'), rawMessage);
    }
  }

  void _handleDecodeError(ProtocolMessageDecodeError error, String rawInput) {
    print('Protocol decode error: $error');
    // Emit an error protocol message for the application to handle
    final errorMsg = ProtocolMessage.error(
      senderId: _participantId,
      errorCode: 'PROTOCOL_DECODE_ERROR',
      errorMessage: error.message,
      sessionId: _sessionId,
      generation: _generation,
    );
    _protocolMessageController.add(errorMsg);
  }

  void _handleProtocolMessage(ProtocolMessage message) {
    _protocolMessageController.add(message);

    switch (ProtocolMessageTypeX.fromWireValue(message.messageType)) {
      case ProtocolMessageType.hello:
        _handleHello(message);
        break;
      case ProtocolMessageType.welcome:
        _handleWelcome(message);
        break;
      case ProtocolMessageType.versionRejected:
        _handleVersionRejected(message);
        break;
      case ProtocolMessageType.ping:
        _handlePing(message);
        break;
      case ProtocolMessageType.pong:
        // Pong is informational, just pass through
        break;
      case ProtocolMessageType.error:
        // Error is informational, just pass through
        break;
      case ProtocolMessageType.roomClosed:
        // Room closed is informational, just pass through
        break;
      case ProtocolMessageType.chat:
        _handleChat(message);
        break;
      case null:
        // Unknown message type, ignore but log
        print('Unknown message type: ${message.messageType}');
        break;
    }
  }

  void _handleChat(ProtocolMessage message) {
    final text = message.payload?['text'] as String?;
    if (text != null && text.isNotEmpty) {
      _messageController.add(text);
    }
  }

  void _handleHello(ProtocolMessage message) {
    if (!_isHost) {
      // Participants don't handle HELLO
      return;
    }

    // If we're in listening state, this is the first participant connecting
    // Transition to handshaking and start the timeout timer
    if (_currentState == NetworkConnectionState.listening) {
      debugPrint('[Handshake] Host: Participant connected (HELLO received), entering handshaking state');
      _transitionTo(NetworkConnectionState.handshaking);
      _startHandshakeTimer();
    }

    final participantVersion = message.protocolVersion;
    if (participantVersion != CURRENT_PROTOCOL_VERSION) {
      final reject = ProtocolMessage.versionRejected(
        hostVersion: CURRENT_PROTOCOL_VERSION,
        participantVersion: participantVersion,
        hostParticipantId: _participantId,
        generation: _generation,
      );
      debugPrint('[Handshake] Host: Sending VERSION_REJECTED: ${reject.toJsonString()}');
      sendProtocolMessage(reject);
      _cancelHandshakeTimer();
      _transitionTo(NetworkConnectionState.failed, reason: 'Version mismatch: host=$CURRENT_PROTOCOL_VERSION participant=$participantVersion');
      return;
    }

    _sessionId = generateUuidV4();
    _roomId = generateUuidV4();
    _generation = 0;

    final welcome = ProtocolMessage.welcome(
      protocolVersion: CURRENT_PROTOCOL_VERSION,
      sessionId: _sessionId!,
      roomId: _roomId!,
      hostParticipantId: _participantId,
      generation: _generation,
    );
    debugPrint('[Handshake] Host: Sending WELCOME: ${welcome.toJsonString()}');
    sendProtocolMessage(welcome);
    _cancelHandshakeTimer();
    _transitionTo(NetworkConnectionState.ready, reason: 'Version match, session established');
  }

  void _handleWelcome(ProtocolMessage message) {
    if (_isHost) {
      // Host doesn't handle WELCOME
      return;
    }

    if (message.protocolVersion != CURRENT_PROTOCOL_VERSION) {
      // Should not happen since host checks version, but handle anyway
      _cancelHandshakeTimer();
      _transitionTo(NetworkConnectionState.failed, reason: 'Welcome version mismatch');
      return;
    }

    _sessionId = message.sessionId;
    _roomId = message.payload?['roomId'] as String?;
    _generation = message.generation;
    _cancelHandshakeTimer();
    _transitionTo(NetworkConnectionState.ready, reason: 'Welcome received, session joined');
  }

  void _handleVersionRejected(ProtocolMessage message) {
    if (_isHost) {
      return;
    }
    _cancelHandshakeTimer();
    _transitionTo(NetworkConnectionState.failed, reason: 'Version rejected by host: hostVersion=${message.payload?['hostVersion']} participantVersion=${message.payload?['participantVersion']}');
  }

  void _handlePing(ProtocolMessage message) {
    final pong = ProtocolMessage.pong(
      senderId: _participantId,
      sessionId: _sessionId,
      generation: _generation,
      originalMessageId: message.messageId,
    );
    sendProtocolMessage(pong);
  }

  void _startHandshakeTimer() {
    _handshakeTimer = Timer(_handshakeTimeout, () {
      if (_currentState == NetworkConnectionState.handshaking) {
        debugPrint('[Handshake] Handshake timeout fired after ${_handshakeTimeout.inSeconds}s, transitioning to failed');
        _transitionTo(NetworkConnectionState.failed, reason: 'Handshake timeout after ${_handshakeTimeout.inSeconds}s');
        _protocolMessageController.add(
          ProtocolMessage.error(
            senderId: _participantId,
            errorCode: 'HANDSHAKE_TIMEOUT',
            errorMessage: 'Handshake timed out',
            sessionId: _sessionId,
            generation: _generation,
          ),
        );
      }
    });
  }

  // Test helper to manually trigger handshake timeout
  void triggerHandshakeTimeoutForTest() {
    if (_currentState == NetworkConnectionState.handshaking) {
      _transitionTo(NetworkConnectionState.failed, reason: 'Test-triggered handshake timeout');
      _protocolMessageController.add(
        ProtocolMessage.error(
          senderId: _participantId,
          errorCode: 'HANDSHAKE_TIMEOUT',
          errorMessage: 'Handshake timed out',
          sessionId: _sessionId,
          generation: _generation,
        ),
      );
    }
  }

  void _cancelHandshakeTimer() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
  }

  void _transitionTo(NetworkConnectionState newState, {String? reason}) {
    if (_currentState == newState) return;
    _currentState = newState;
    _stateController.add(_currentState);
    if (newState == NetworkConnectionState.ready || newState == NetworkConnectionState.failed) {
      debugPrint('[Handshake] State transition: ${_currentState.name} -> $newState${reason != null ? ' (reason: $reason)' : ''}');
    }
  }

  NetworkConnectionState _parseState(String state) {
    switch (state) {
      case 'connecting':
        return NetworkConnectionState.connecting;
      case 'connected':
        return NetworkConnectionState.connected;
      case 'listening':
        return NetworkConnectionState.listening;
      case 'failed':
        return NetworkConnectionState.failed;
      case 'disconnected':
        return NetworkConnectionState.disconnected;
      default:
        return NetworkConnectionState.disconnected;
    }
  }

  void dispose() {
    _cancelHandshakeTimer();
    _stateController.close();
    _messageController.close();
    _protocolMessageController.close();
    _connectionErrorController.close();
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
  final void Function(String, String) onErrorCallback;

  _NetworkFlutterApi({
    required this.onMessageCallback,
    required this.onStateCallback,
    required this.onErrorCallback,
  });

  @override
  void onMessageReceived(String message) {
    onMessageCallback(message);
  }

  @override
  void onConnectionStateChanged(String state) {
    onStateCallback(state);
  }

  @override
  void onConnectionError(String errorCode, String errorMessage) {
    onErrorCallback(errorCode, errorMessage);
  }
}