import 'dart:async';
import 'dart:math';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';
import '../protocol.dart';
import '../room/room_lifecycle.dart';

const Duration _handshakeTimeout = Duration(seconds: 10);

String _generateParticipantId() => generateUuidV4();

class _MockNetworkHostPlatform extends NetworkHostPlatform {
  @override
  Future<bool> startHosting(int port) async => true;

  @override
  Future<bool> connectToHost(String ipAddress, int port) async => true;

  @override
  Future<bool> sendChatMessage(String text) async => true;

  @override
  Future<bool> sendProtocolMessage(String message) async => true;

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
  reconnecting,
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
  final StreamController<RoomLifecycleState> _roomLifecycleStateController =
      StreamController<RoomLifecycleState>.broadcast();

  NetworkConnectionState _currentState = NetworkConnectionState.disconnected;
  RoomLifecycleState _roomLifecycleState = RoomLifecycleState.created;
  late final _NetworkFlutterApi _flutterApi;

  final String _participantId = _generateParticipantId();
  String? _sessionId;
  String? _roomId;

  /// Room identifier pre-assigned by the host at room creation. When set, the
  /// WELCOME handshake advertises this ID instead of generating a new one, so
  /// the discovery announcement and the actual room identity agree.
  String? _hostRoomId;

  int _generation = 0;
  bool _isHost = false;
  bool _handshakeInitiated = false;
  Timer? _handshakeTimer;

  RoomRole _roomRole = RoomRole.host;
  String? _participantDisplayName;
  bool _participantJoined = false;
  String? _roomClosedReason;

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
        debugPrint('[DartLifecycle] onStateCallback received: state=$state, _isHost=$_isHost, _currentState=$_currentState');
        // For host, "connected" from native means ServerSocket is listening
        // For participant, "connected" means TCP connection established
        if (_isHost && state == 'connected') {
          _currentState = NetworkConnectionState.listening;
          _stateController.add(_currentState);
          debugPrint('[DartLifecycle] Host: Transitioned to listening state');
          _onTcpConnected(); // This will handle host listening logic
        } else {
          _currentState = _parseState(state);
          _stateController.add(_currentState);
          debugPrint('[DartLifecycle] Transitioned to $_currentState from native state=$state');

          if (_currentState == NetworkConnectionState.connected) {
            _onTcpConnected();
          } else if (_currentState == NetworkConnectionState.reconnecting) {
            debugPrint('[DartLifecycle] Entered reconnecting state');
          }
        }
      },
      onErrorCallback: (errorCode, errorMessage) {
        debugPrint('[Connection] Error from native: code=$errorCode, message=$errorMessage');
        _connectionErrorController.add(ConnectionError(errorCode, errorMessage));
        
        // Handle specific error codes
        switch (errorCode) {
          case 'HEARTBEAT_TIMEOUT':
            debugPrint('[Connection] Heartbeat timeout - will trigger reconnection on participant side');
            // The native side handles reconnection for participants
            // For host, the participant is considered lost
            if (_isHost) {
              _transitionTo(NetworkConnectionState.disconnected, reason: 'Participant heartbeat timeout');
              _resetHostParticipantState(resetIds: true);
            }
            break;
          case 'RECONNECTION_FAILED':
            debugPrint('[Connection] Reconnection failed after max attempts');
            _transitionTo(NetworkConnectionState.failed, reason: 'Reconnection failed: $errorMessage');
            break;
          case 'PROTOCOL_VERSION_MISMATCH':
          case 'HANDSHAKE_FAILED':
            debugPrint('[Connection] Protocol version mismatch or handshake failed');
            _transitionTo(NetworkConnectionState.failed, reason: 'Protocol error: $errorCode - $errorMessage');
            break;
          case 'NETWORK_UNREACHABLE':
          case 'CONNECTION_REFUSED':
          case 'CONNECTION_TIMEOUT':
          case 'UNKNOWN_HOST':
          case 'SOCKET_ERROR':
          case 'CONNECTION_FAILED':
            // Also transition to failed state if we're in connecting state
            if (_currentState == NetworkConnectionState.connecting) {
              _transitionTo(NetworkConnectionState.failed, reason: 'Connection error: $errorCode - $errorMessage');
            }
            break;
        }
      },
    );
    NetworkFlutterApi.setUp(_flutterApi);
    _transitionToRoomLifecycleState(RoomLifecycleState.created);
  }

  String get participantId => _participantId;
  String? get sessionId => _sessionId;
  String? get roomId => _roomId;
  int get generation => _generation;
  bool get isHost => _isHost;
  RoomRole get roomRole => _roomRole;
  RoomLifecycleState get roomLifecycleState => _roomLifecycleState;
  bool get participantJoined => _participantJoined;
  String? get roomClosedReason => _roomClosedReason;

  Stream<NetworkConnectionState> get connectionStateStream =>
      _stateController.stream;

  Stream<String> get messageStream => _messageController.stream;

  Stream<ProtocolMessage> get protocolMessageStream =>
      _protocolMessageController.stream;

  Stream<ConnectionError> get connectionErrorStream =>
      _connectionErrorController.stream;

  Stream<RoomLifecycleState> get roomLifecycleStateStream =>
      _roomLifecycleStateController.stream;

  NetworkConnectionState get currentState => _currentState;

  Future<bool> startHosting({int port = 8765, String? roomId}) async {
    developer.log(
      'startHosting called, port=$port, roomId=$roomId',
      name: 'SoundMesh.NetworkRepository',
    );
    _isHost = true;
    _hostRoomId = roomId;
    _roomRole = RoomRole.host;
    _handshakeInitiated = false;
    _roomClosedReason = null;
    _transitionToRoomLifecycleState(RoomLifecycleState.created);
    try {
      return await _platform.startHosting(port);
    } catch (e) {
      developer.log(
        'startHosting threw exception: $e',
        name: 'SoundMesh.NetworkRepository',
      );
      return false;
    }
  }

  Future<bool> connectToHost(String ipAddress, {int port = 8765}) async {
    developer.log(
      '[JOIN_TRACE] NetworkRepository: connectToHost ENTERED ip=$ipAddress port=$port',
      name: 'SoundMesh.NetworkRepository',
    );
    _isHost = false;
    _roomRole = RoomRole.participant;
    _handshakeInitiated = false;
    _roomClosedReason = null;
    _transitionToRoomLifecycleState(RoomLifecycleState.created);
    developer.log(
      '[JOIN_TRACE] NetworkRepository: Initiating TCP connect to $ipAddress:$port',
      name: 'SoundMesh.NetworkRepository',
    );
    try {
      final result = await _platform.connectToHost(ipAddress, port);
      developer.log(
        '[JOIN_TRACE] NetworkRepository: connectToHost returned: $result',
        name: 'SoundMesh.NetworkRepository',
      );
      return result;
    } catch (e) {
      developer.log(
        '[JOIN_TRACE] NetworkRepository: TCP connect threw exception: $e',
        name: 'SoundMesh.NetworkRepository',
      );
      return false;
    }
  }

  Future<bool> sendChatMessage(String text) async {
    debugPrint('[HandshakeTrace] Dart: sendChatMessage called, text length=${text.length}');
    debugPrint('[HandshakeTrace] Dart: creating ProtocolMessage.chat envelope');
    final chatMessage = ProtocolMessage.chat(
      senderId: _participantId,
      text: text,
      sessionId: _sessionId,
      generation: _generation,
    );
    debugPrint('[HandshakeTrace] Dart: about to invoke platform sendChatMessage');
    final result = await _platform.sendChatMessage(chatMessage.toJsonString());
    debugPrint('[HandshakeTrace] Dart: platform sendChatMessage returned result=$result');
    return result;
  }

  Future<bool> sendProtocolMessage(ProtocolMessage message) async {
    debugPrint('[HandshakeTrace] Dart: sendProtocolMessage called, messageType=${message.messageType}, message=${message.toJsonString().substring(0, min(100, message.toJsonString().length))}...');
    debugPrint('[HandshakeTrace] Dart: about to invoke platform sendProtocolMessage (raw protocol)');
    final result = await _platform.sendProtocolMessage(message.toJsonString());
    debugPrint('[HandshakeTrace] Dart: platform sendProtocolMessage returned result=$result');
    return result;
  }

  Future<void> disconnect() async {
    debugPrint('[DartLifecycle] disconnect() called');
    try {
      await _platform.disconnect();
    } catch (e) {
      debugPrint('[DartLifecycle] disconnect threw exception: $e');
    }
    _resetHandshakeState();
  }

  Future<void> setHeartbeatConfig({int intervalMs = 5000, int timeoutMs = 15000}) async {
    debugPrint('[DartLifecycle] setHeartbeatConfig called: intervalMs=$intervalMs, timeoutMs=$timeoutMs');
    try {
      await _platform.setHeartbeatConfig(intervalMs, timeoutMs);
    } catch (e) {
      debugPrint('[DartLifecycle] setHeartbeatConfig threw exception: $e');
    }
  }

  Future<bool> reconnectToHost(String ipAddress, {int port = 8765}) async {
    debugPrint('[DartLifecycle] reconnectToHost called, ip=$ipAddress, port=$port');
    try {
      return await _platform.reconnectToHost(ipAddress, port);
    } catch (e) {
      debugPrint('[DartLifecycle] reconnectToHost threw exception: $e');
      return false;
    }
  }

  Future<void> closeRoom() async {
    debugPrint('[DartLifecycle] closeRoom() called, _isHost=$_isHost, _roomLifecycleState=$_roomLifecycleState');
    if (!_isHost) {
      // Only host can close room
      return;
    }
    if (_roomLifecycleState == RoomLifecycleState.closed) {
      return;
    }

    // roomId only exists after the first HELLO was processed. A host closing
    // the room before any participant joined must still end the room locally
    // instead of crashing on a null assertion.
    final roomId = _roomId;
    if (roomId != null) {
      final roomClosed = ProtocolMessage.roomClosed(
        senderId: _participantId,
        roomId: roomId,
        sessionId: _sessionId,
        generation: _generation,
        reason: 'Host ended the room',
      );
      debugPrint('[RoomLifecycle] Host: Sending ROOM_CLOSED: ${roomClosed.toJsonString()}');
      await sendProtocolMessage(roomClosed);
    }

    _roomClosedReason = 'Room ended';
    _transitionToRoomLifecycleState(RoomLifecycleState.closed);
    _transitionTo(NetworkConnectionState.disconnected);
    await _platform.disconnect();
    _resetHandshakeState();
  }

  Future<void> leaveRoom() async {
    debugPrint('[DartLifecycle] leaveRoom() called, _isHost=$_isHost, _roomLifecycleState=$_roomLifecycleState');
    if (_isHost) {
      // Host should use closeRoom
      return;
    }
    if (_roomLifecycleState == RoomLifecycleState.closed) {
      return;
    }

    _roomClosedReason = 'You left the room';
    _transitionToRoomLifecycleState(RoomLifecycleState.closed);
    _transitionTo(NetworkConnectionState.disconnected);
    await _platform.disconnect();
    _resetHandshakeState();
  }

  void setParticipantDisplayName(String? displayName) {
    _participantDisplayName = displayName;
  }

  Future<String> getLocalIpAddress() async {
    try {
      return await _platform.getLocalIpAddress();
    } catch (e) {
      return '127.0.0.1';
    }
  }

  void _resetHandshakeState() {
    debugPrint('[DartLifecycle] _resetHandshakeState called');
    _cancelHandshakeTimer();
    _sessionId = null;
    _roomId = null;
    _generation = 0;
    _handshakeInitiated = false;
    _participantJoined = false;
    // _roomClosedReason is intentionally kept: consumers (UI state providers)
    // read it after the closed transition, and _resetHandshakeState runs before
    // those reads complete. It is cleared when a new session begins instead.
  }

  void _transitionToRoomLifecycleState(RoomLifecycleState newState) {
    if (_roomLifecycleState == newState) return;
    developer.log(
      'RoomLifecycleState transition: ${_roomLifecycleState.name} → ${newState.name}',
      name: 'SoundMesh.NetworkRepository',
    );
    _roomLifecycleState = newState;
    _roomLifecycleStateController.add(_roomLifecycleState);
  }

  void _onTcpConnected() {
    _cancelHandshakeTimer();
    if (_isHost) {
      developer.log(
        'Host: TCP listener ready, emitting discoverable',
        name: 'SoundMesh.NetworkRepository',
      );
      _transitionTo(NetworkConnectionState.listening);
      _transitionToRoomLifecycleState(RoomLifecycleState.discoverable);
      // Do NOT start handshake timer here - wait for participant to connect (HELLO received)
    } else {
      developer.log(
        'Participant: TCP connected, sending HELLO',
        name: 'SoundMesh.NetworkRepository',
      );
      _sendHello();
      _transitionTo(NetworkConnectionState.handshaking);
      _transitionToRoomLifecycleState(RoomLifecycleState.joining);
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
      protocolVersion: currentProtocolVersion,
      participantId: _participantId,
      generation: _generation,
    );
    debugPrint('[Handshake] Participant: Sending HELLO: ${hello.toJsonString()}');
    debugPrint('[HandshakeTrace] Dart: calling sendProtocolMessage');
    sendProtocolMessage(hello);
    debugPrint('[Handshake] Participant: HELLO sendProtocolMessage completed');
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
    debugPrint('Protocol decode error: $error');
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
        _handleRoomClosed(message);
        break;
      case ProtocolMessageType.chat:
        _handleChat(message);
        break;
      case ProtocolMessageType.joinRequest:
        _handleJoinRequest(message);
        break;
      case ProtocolMessageType.joinAccepted:
        _handleJoinAccepted(message);
        break;
      case ProtocolMessageType.joinRejected:
        _handleJoinRejected(message);
        break;
      case null:
        // Unknown message type, ignore but log
        debugPrint('Unknown message type: ${message.messageType}');
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
      setHeartbeatConfig(); // Configure heartbeat for the new connection
    }

    final participantVersion = message.protocolVersion;
    if (participantVersion != currentProtocolVersion) {
      final reject = ProtocolMessage.versionRejected(
        hostVersion: currentProtocolVersion,
        participantVersion: participantVersion,
        hostParticipantId: _participantId,
        generation: _generation,
      );
      debugPrint('[Handshake] Host: Sending VERSION_REJECTED: ${reject.toJsonString()}');
      sendProtocolMessage(reject);
      _cancelHandshakeTimer();
      _transitionTo(NetworkConnectionState.failed, reason: 'Version mismatch: host=$currentProtocolVersion participant=$participantVersion');
      return;
    }

    // A HELLO after a participant has joined is a duplicate from the same
    // connection; re-sending WELCOME would trigger a room-full rejection that
    // kicks the joined participant.
    if (_participantJoined) {
      debugPrint('[RoomLifecycle] Host: Duplicate HELLO after participant joined, ignoring');
      return;
    }

    // Session/room IDs are created once per hosting session. A duplicate HELLO
    // (e.g. a retried connection) must not rotate IDs that a participant may
    // already have received in a WELCOME. The room ID is pre-assigned by the
    // host at room creation so it matches the discovery announcement.
    _sessionId ??= generateUuidV4();
    _roomId ??= _hostRoomId ?? generateUuidV4();
    _generation = 0;

    final welcome = ProtocolMessage.welcome(
      protocolVersion: currentProtocolVersion,
      sessionId: _sessionId!,
      roomId: _roomId!,
      hostParticipantId: _participantId,
      generation: _generation,
    );
    debugPrint('[Handshake] Host: Sending WELCOME: ${welcome.toJsonString()}');
    sendProtocolMessage(welcome);
    // Don't cancel handshake timer or transition to ready yet - wait for JOIN_REQUEST
  }

  void _handleWelcome(ProtocolMessage message) {
    if (_isHost) {
      // Host doesn't handle WELCOME
      return;
    }

    if (message.protocolVersion != currentProtocolVersion) {
      // Should not happen since host checks version, but handle anyway
      _cancelHandshakeTimer();
      _transitionTo(NetworkConnectionState.failed, reason: 'Welcome version mismatch');
      return;
    }

    // sessionId is not a protocol-required field; a malformed WELCOME without
    // one cannot be joined.
    if (message.sessionId == null) {
      debugPrint('[Handshake] Participant: WELCOME missing sessionId, failing handshake');
      _cancelHandshakeTimer();
      _transitionTo(NetworkConnectionState.failed, reason: 'Welcome missing sessionId');
      return;
    }

    _sessionId = message.sessionId;
    _roomId = message.payload?['roomId'] as String?;
    _generation = message.generation;

    // Configure heartbeat now that session is established
    setHeartbeatConfig();

    // Send JOIN_REQUEST to formally join the room
    final joinRequest = ProtocolMessage.joinRequest(
      participantId: _participantId,
      displayName: _participantDisplayName,
      sessionId: _sessionId!,
      generation: _generation,
    );
    debugPrint('[Handshake] Participant: Sending JOIN_REQUEST: ${joinRequest.toJsonString()}');
    sendProtocolMessage(joinRequest);
    // Wait for JOIN_ACCEPTED or JOIN_REJECTED
  }

  void _handleVersionRejected(ProtocolMessage message) {
    if (_isHost) {
      return;
    }
    _cancelHandshakeTimer();
    _transitionTo(NetworkConnectionState.failed, reason: 'Version rejected by host: hostVersion=${message.payload?['hostVersion']} participantVersion=${message.payload?['participantVersion']}');
  }

  void _handlePing(ProtocolMessage message) {
    // Validate sessionId matches current session to avoid responding to stale PINGs
    if (message.sessionId != null && message.sessionId != _sessionId) {
      debugPrint('[Handshake] Ignoring PING from stale session: ${message.sessionId} (current: $_sessionId)');
      return;
    }
    final pong = ProtocolMessage.pong(
      senderId: _participantId,
      sessionId: _sessionId,
      generation: _generation,
      originalMessageId: message.messageId,
    );
    sendProtocolMessage(pong);
  }

  void _handleJoinRequest(ProtocolMessage message) {
    if (!_isHost) {
      return;
    }

    final participantId = message.payload?['participantId'] as String?;
    if (participantId == null) {
      debugPrint('[RoomLifecycle] Host: JOIN_REQUEST missing participantId, ignoring');
      return;
    }

    // A JOIN_REQUEST can only be answered after a HELLO established the
    // session/room IDs; without them the host would crash on a null assertion
    // when building the response.
    if (_sessionId == null || _roomId == null) {
      debugPrint('[RoomLifecycle] Host: JOIN_REQUEST before handshake, ignoring');
      return;
    }

    if (_participantJoined) {
      // Reject second participant - room full
      debugPrint('[RoomLifecycle] Host: Second JOIN_REQUEST from $participantId, rejecting (room full)');
      final reject = ProtocolMessage.joinRejected(
        sessionId: _sessionId!,
        reason: JoinRejectReason.roomFull,
        generation: _generation,
      );
      sendProtocolMessage(reject);
      return;
    }

    // Accept the participant
    _participantJoined = true;
    _cancelHandshakeTimer();
    _transitionTo(NetworkConnectionState.ready, reason: 'Participant joined');
    _transitionToRoomLifecycleState(RoomLifecycleState.ready);

    final accept = ProtocolMessage.joinAccepted(
      sessionId: _sessionId!,
      roomId: _roomId!,
      hostParticipantId: _participantId,
      participantId: participantId,
      generation: _generation,
    );
    debugPrint('[RoomLifecycle] Host: Sending JOIN_ACCEPTED: ${accept.toJsonString()}');
    sendProtocolMessage(accept);
  }

  void _handleJoinAccepted(ProtocolMessage message) {
    if (_isHost) {
      return;
    }

    _cancelHandshakeTimer();
    _transitionTo(NetworkConnectionState.ready, reason: 'Join accepted');
    _transitionToRoomLifecycleState(RoomLifecycleState.ready);
    // Handshake complete - heartbeat already configured in _handleWelcome
  }

  void _handleJoinRejected(ProtocolMessage message) {
    if (_isHost) {
      return;
    }

    // Store a human-readable reason: raw wire values (e.g. ROOM_FULL) must not
    // leak into UI-facing state.
    final reasonStr = message.payload?['reason'] as String?;
    final reason = JoinRejectReasonX.fromWireValue(reasonStr ?? '') ?? JoinRejectReason.internalError;
    _cancelHandshakeTimer();
    _roomClosedReason = reason.friendlyMessage;
    _transitionTo(NetworkConnectionState.failed, reason: 'Join rejected: ${reason.wireValue}');
    _transitionToRoomLifecycleState(RoomLifecycleState.closed);
  }

  void _handleRoomClosed(ProtocolMessage message) {
    final reason = message.payload?['reason'] as String?;
    _roomClosedReason = reason ?? 'Room closed by host';

    if (_isHost) {
      // Host receives ROOM_CLOSED from participant (or echo of own)
      _transitionToRoomLifecycleState(RoomLifecycleState.closed);
      _transitionTo(NetworkConnectionState.disconnected);
    } else {
      // Participant receives ROOM_CLOSED from host
      _transitionToRoomLifecycleState(RoomLifecycleState.closed);
      _transitionTo(NetworkConnectionState.disconnected);
    }
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
    if (_handshakeTimer != null) {
      debugPrint('[HandshakeTimer] Cancelling handshake timer, currentState=$_currentState');
      _handshakeTimer!.cancel();
      _handshakeTimer = null;
    }
  }

  void _startHandshakeTimer() {
    debugPrint('[HandshakeTimer] Starting handshake timer (${_handshakeTimeout.inSeconds}s), currentState=$_currentState');
    _handshakeTimer = Timer(_handshakeTimeout, () {
      debugPrint('[HandshakeTimer] Timer fired! currentState=$_currentState, _isHost=$_isHost');
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
      } else {
        debugPrint('[HandshakeTimer] Timer fired but not in handshaking state (state=$_currentState), ignoring');
      }
    });
  }

  void _resetHostParticipantState({bool resetIds = true}) {
    if (!_isHost) return;
    debugPrint('[DartLifecycle] _resetHostParticipantState called, resetIds=$resetIds');
    _participantJoined = false;
    if (resetIds) {
      _sessionId = null;
      _roomId = null;
      _generation = 0;
    }
    _cancelHandshakeTimer();
  }

  void _transitionTo(NetworkConnectionState newState, {String? reason}) {
    if (_currentState == newState) return;
    debugPrint('[DartLifecycle] ConnectionState transition: ${_currentState.name} -> $newState${reason != null ? ' (reason: $reason)' : ''} (caller: ${StackTrace.current.toString().split('\n')[1].trim()})');
    
    // If host loses participant connection, reset participant state so a new participant can join
    if (_isHost && newState == NetworkConnectionState.disconnected && _currentState != NetworkConnectionState.disconnected) {
      // Only reset if we were in a connected/handshaking state, not if we're intentionally closing
      final wasConnected = _currentState == NetworkConnectionState.ready || 
                           _currentState == NetworkConnectionState.handshaking ||
                           _currentState == NetworkConnectionState.connected ||
                           _currentState == NetworkConnectionState.listening;
      if (wasConnected) {
        _resetHostParticipantState(resetIds: true);
      }
    }
    
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
      case 'reconnecting':
        return NetworkConnectionState.reconnecting;
      case 'failed':
        return NetworkConnectionState.failed;
      case 'disconnected':
        return NetworkConnectionState.disconnected;
      default:
        return NetworkConnectionState.disconnected;
    }
  }

  // Test helper to simulate native error callback
  void handleErrorCallbackForTest(String errorCode, String errorMessage) {
    debugPrint('[Test] Simulating error callback: $errorCode - $errorMessage');
    _connectionErrorController.add(ConnectionError(errorCode, errorMessage));
    
    // Handle specific error codes (same logic as in _init)
    switch (errorCode) {
      case 'HEARTBEAT_TIMEOUT':
        debugPrint('[Connection] Heartbeat timeout - will trigger reconnection on participant side');
        if (_isHost) {
          _transitionTo(NetworkConnectionState.disconnected, reason: 'Participant heartbeat timeout');
          _resetHostParticipantState(resetIds: true);
        }
        break;
      case 'RECONNECTION_FAILED':
        debugPrint('[Connection] Reconnection failed after max attempts');
        _transitionTo(NetworkConnectionState.failed, reason: 'Reconnection failed: $errorMessage');
        break;
      case 'PROTOCOL_VERSION_MISMATCH':
      case 'HANDSHAKE_FAILED':
        debugPrint('[Connection] Protocol version mismatch or handshake failed');
        _transitionTo(NetworkConnectionState.failed, reason: 'Protocol error: $errorCode - $errorMessage');
        break;
      case 'NETWORK_UNREACHABLE':
      case 'CONNECTION_REFUSED':
      case 'CONNECTION_TIMEOUT':
      case 'UNKNOWN_HOST':
      case 'SOCKET_ERROR':
      case 'CONNECTION_FAILED':
        if (_currentState == NetworkConnectionState.connecting) {
          _transitionTo(NetworkConnectionState.failed, reason: 'Connection error: $errorCode - $errorMessage');
        }
        break;
    }
  }

  void dispose() {
    _cancelHandshakeTimer();
    _stateController.close();
    _messageController.close();
    _protocolMessageController.close();
    _connectionErrorController.close();
    _roomLifecycleStateController.close();
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