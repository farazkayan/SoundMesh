import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/presentation/screens/room_screen.dart';

class MockNetworkRepository extends NetworkRepository {
  late final StreamController<NetworkConnectionState> _stateController;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final StreamController<ProtocolMessage> _protocolMessageController =
      StreamController<ProtocolMessage>.broadcast();
  final StreamController<RoomLifecycleState> _roomLifecycleStateController =
      StreamController<RoomLifecycleState>.broadcast();

  NetworkConnectionState _currentState = NetworkConnectionState.disconnected;
  RoomLifecycleState _roomLifecycleState = RoomLifecycleState.created;
  final String _participantId = '550e8400-e29b-41d4-a716-446655440000';
  String? _sessionId;
  String? _roomId;
  final int _generation = 0;
  bool _isHost = false;
  RoomRole _roomRole = RoomRole.host;

  MockNetworkRepository() {
    _stateController = StreamController<NetworkConnectionState>.broadcast(
      onListen: () {
        _stateController.add(_currentState);
      },
    );
    _roomLifecycleStateController.add(_roomLifecycleState);
  }

  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  Stream<ProtocolMessage> get protocolMessageStream =>
      _protocolMessageController.stream;

  @override
  Stream<RoomLifecycleState> get roomLifecycleStateStream =>
      _roomLifecycleStateController.stream;

  @override
  NetworkConnectionState get currentState => _currentState;

  @override
  RoomLifecycleState get roomLifecycleState => _roomLifecycleState;

  @override
  String get participantId => _participantId;

  @override
  String? get sessionId => _sessionId;

  @override
  String? get roomId => _roomId;

  @override
  int get generation => _generation;

  @override
  bool get isHost => _isHost;

  @override
  RoomRole get roomRole => _roomRole;

  void setState(NetworkConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void setRoomLifecycleState(RoomLifecycleState state) {
    _roomLifecycleState = state;
    _roomLifecycleStateController.add(state);
  }

  void setHostMode(bool isHost) {
    _isHost = isHost;
    _roomRole = isHost ? RoomRole.host : RoomRole.participant;
  }

  void setSessionId(String? id) {
    _sessionId = id;
  }

  void setRoomId(String? id) {
    _roomId = id;
  }

  void emitMessage(String message) {
    _messageController.add(message);
  }

  void emitProtocolMessage(ProtocolMessage message) {
    _protocolMessageController.add(message);
  }

  Future<bool> sendMessage(String message) async => true;

  @override
  Future<bool> sendProtocolMessage(ProtocolMessage message) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> setHeartbeatConfig({int intervalMs = 5000, int timeoutMs = 15000}) async {}

  @override
  Future<bool> reconnectToHost(String ipAddress, {int port = 8765}) async => false;

  @override
  void dispose() {
    _stateController.close();
    _messageController.close();
    _protocolMessageController.close();
    _roomLifecycleStateController.close();
  }
}

class MockCreateRoomFlowNotifier extends CreateRoomFlowNotifier {
  MockCreateRoomFlowNotifier(CreateRoomFlowState state, NetworkRepository networkRepo)
      : super(networkRepo) {
    this.state = state;
  }
}

class MockJoinRoomFlowNotifier extends JoinRoomFlowNotifier {
  MockJoinRoomFlowNotifier(JoinRoomFlowState state, NetworkRepository networkRepo)
      : super(networkRepo) {
    this.state = state;
  }
}

class MockRoomLifecycleNotifier extends RoomLifecycleNotifier {
  final RoomLifecycleStateData _stateData;
  final StreamController<RoomLifecycleStateData> _controller =
      StreamController<RoomLifecycleStateData>.broadcast();

  MockRoomLifecycleNotifier(this._stateData, NetworkRepository networkRepo)
      : super(networkRepo) {
    _controller.add(_stateData);
    state = _stateData;
  }

  @override
  Stream<RoomLifecycleStateData> get stream => _controller.stream;

  void updateState(RoomLifecycleStateData newState) {
    state = newState;
    _controller.add(newState);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

void main() {
  group('RoomScreen handshake widget tests', () {
    testWidgets('shows handshaking indicator during handshake', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.handshaking);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.joining);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.handshaking,
        connectionState: NetworkConnectionState.handshaking,
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.joining,
        role: RoomRole.host,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(createState, networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(const JoinRoomFlowState(), networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Handshaking...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

testWidgets('shows ready state after handshake completes (host)', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.ready);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.ready);
      networkRepo.setSessionId('session-123');
      networkRepo.setRoomId('room-123');

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
        sessionId: 'session-123',
        roomId: 'room-123',
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.ready,
        role: RoomRole.host,
        sessionId: 'session-123',
        roomId: 'room-123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(createState, networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(const JoinRoomFlowState(), networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Check app bar title shows "Host" which indicates ready state
      expect(find.text('Host'), findsOneWidget);
      expect(find.text('Handshaking...'), findsNothing);
    });

testWidgets('shows ready state after handshake completes (participant)', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(false);
      networkRepo.setState(NetworkConnectionState.ready);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.ready);
      networkRepo.setSessionId('session-123');
      networkRepo.setRoomId('room-123');

      final joinState = JoinRoomFlowState(
        status: JoinRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
        sessionId: 'session-123',
        roomId: 'room-123',
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.ready,
        role: RoomRole.participant,
        sessionId: 'session-123',
        roomId: 'room-123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(const CreateRoomFlowState(), networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(joinState, networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Check app bar title shows "Participant" which indicates ready state
      expect(find.text('Participant'), findsOneWidget);
      expect(find.text('Handshaking...'), findsNothing);
    });

    testWidgets('message input is disabled during handshaking', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.handshaking);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.joining);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.handshaking,
        connectionState: NetworkConnectionState.handshaking,
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.joining,
        role: RoomRole.host,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(createState, networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(const JoinRoomFlowState(), networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Find the TextField and verify it's disabled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
      expect(textField.decoration?.hintText, equals('Waiting for handshake...'));
    });

    testWidgets('message input is enabled when ready', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.ready);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.ready);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.ready,
        role: RoomRole.host,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(createState, networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(const JoinRoomFlowState(), networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);
      expect(textField.decoration?.hintText, equals('Type a message...'));
    });

    testWidgets('shows version mismatch error', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(false);
      networkRepo.setState(NetworkConnectionState.failed);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.closed);

      final joinState = JoinRoomFlowState(
        status: JoinRoomFlowStatus.failed,
        connectionState: NetworkConnectionState.failed,
        errorMessage: 'Protocol version mismatch: host v2 vs this device v1',
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.closed,
        role: RoomRole.participant,
        closedReason: 'Protocol version mismatch: host v2 vs this device v1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(const CreateRoomFlowState(), networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(joinState, networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Emit a VERSION_REJECTED protocol message
      networkRepo.emitProtocolMessage(
        ProtocolMessage(
          protocolVersion: 2,
          messageId: '550e8400-e29b-41d4-a716-446655440000',
          messageType: 'VERSION_REJECTED',
          senderId: '550e8400-e29b-41d4-a716-446655440001',
          generation: 0,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'hostVersion': 2,
            'participantVersion': 1,
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Protocol version mismatch: host v2 vs this device v1'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('shows protocol decode error', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.ready);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.ready);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.ready,
        role: RoomRole.host,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(createState, networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(const JoinRoomFlowState(), networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Emit a protocol decode error
      networkRepo.emitProtocolMessage(
        ProtocolMessage.error(
          senderId: '550e8400-e29b-41d4-a716-446655440000',
          errorCode: 'PROTOCOL_DECODE_ERROR',
          errorMessage: 'Invalid JSON',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Protocol error: Invalid JSON'), findsOneWidget);
    });

    testWidgets('error banner persists when unrelated events arrive', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.ready);
      networkRepo.setRoomLifecycleState(RoomLifecycleState.ready);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.ready,
        role: RoomRole.host,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(networkRepo),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(createState, networkRepo),
            ),
            joinRoomFlowProvider.overrideWith(
              (_) => MockJoinRoomFlowNotifier(const JoinRoomFlowState(), networkRepo),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, networkRepo),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      networkRepo.emitProtocolMessage(
        ProtocolMessage.error(
          senderId: '550e8400-e29b-41d4-a716-446655440000',
          errorCode: 'PROTOCOL_DECODE_ERROR',
          errorMessage: 'Invalid JSON',
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Protocol error: Invalid JSON'), findsOneWidget);

      // A chat message and a connection-state update are unrelated to the
      // error and must not wipe the banner.
      networkRepo.emitMessage('hello from peer');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Protocol error: Invalid JSON'), findsOneWidget);

      networkRepo.setState(NetworkConnectionState.ready);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Protocol error: Invalid JSON'), findsOneWidget);
    });
  });
}