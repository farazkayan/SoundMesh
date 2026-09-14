import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/presentation/screens/room_screen.dart';

class MockNetworkRepository extends NetworkRepository {
  late final StreamController<NetworkConnectionState> _stateController;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final StreamController<ProtocolMessage> _protocolMessageController =
      StreamController<ProtocolMessage>.broadcast();

  NetworkConnectionState _currentState = NetworkConnectionState.disconnected;
  String _participantId = '550e8400-e29b-41d4-a716-446655440000';
  String? _sessionId;
  String? _roomId;
  int _generation = 0;
  bool _isHost = false;

  MockNetworkRepository() {
    _stateController = StreamController<NetworkConnectionState>.broadcast(
      onListen: () {
        _stateController.add(_currentState);
      },
    );
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
  NetworkConnectionState get currentState => _currentState;

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

  void setState(NetworkConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void setHostMode(bool isHost) {
    _isHost = isHost;
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

  @override
  Future<bool> sendMessage(String message) async => true;

  @override
  Future<bool> sendProtocolMessage(ProtocolMessage message) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    _stateController.close();
    _messageController.close();
    _protocolMessageController.close();
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

void main() {
  group('RoomScreen handshake widget tests', () {
    testWidgets('shows handshaking indicator during handshake', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.handshaking);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.handshaking,
        connectionState: NetworkConnectionState.handshaking,
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
      networkRepo.setSessionId('session-123');
      networkRepo.setRoomId('room-123');

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
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
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Check connection indicator in app bar shows "Ready"
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Handshaking...'), findsNothing);
    });

    testWidgets('shows ready state after handshake completes (participant)', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(false);
      networkRepo.setState(NetworkConnectionState.ready);
      networkRepo.setSessionId('session-123');
      networkRepo.setRoomId('room-123');

      final joinState = JoinRoomFlowState(
        status: JoinRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
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
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Check connection indicator in app bar shows "Ready"
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Handshaking...'), findsNothing);
    });

    testWidgets('message input is disabled during handshaking', (
      WidgetTester tester,
    ) async {
      final networkRepo = MockNetworkRepository();
      networkRepo.setHostMode(true);
      networkRepo.setState(NetworkConnectionState.handshaking);

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.handshaking,
        connectionState: NetworkConnectionState.handshaking,
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

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
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

      final joinState = JoinRoomFlowState(
        status: JoinRoomFlowStatus.failed,
        connectionState: NetworkConnectionState.failed,
        errorMessage: 'Protocol version mismatch: host v2 vs this device v1',
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

      final createState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        connectionState: NetworkConnectionState.ready,
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
  });
}