import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/presentation/screens/room_screen.dart';

class MockNetworkRepository extends NetworkRepository {
  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      Stream.value(NetworkConnectionState.ready);

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  Stream<RoomLifecycleState> get roomLifecycleStateStream =>
      Stream.value(RoomLifecycleState.ready);

  @override
  NetworkConnectionState get currentState => NetworkConnectionState.ready;

  @override
  RoomLifecycleState get roomLifecycleState => RoomLifecycleState.ready;

  @override
  RoomRole get roomRole => RoomRole.host;
}

class MockCreateRoomFlowNotifier extends CreateRoomFlowNotifier {
  MockCreateRoomFlowNotifier(CreateRoomFlowState state)
    : super(MockNetworkRepository()) {
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
  group('RoomScreen host widget tests', () {
    testWidgets('shows the host address with a copy action', (
      WidgetTester tester,
    ) async {
      const hostState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        localIpAddress: '192.168.1.100',
        port: 8765,
      );

      final lifecycleState = RoomLifecycleStateData(
        lifecycleState: RoomLifecycleState.ready,
        role: RoomRole.host,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(
              MockNetworkRepository(),
            ),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(hostState),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
            ),
          ],
          child: const MaterialApp(home: RoomScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Host'), findsOneWidget);
      expect(find.text('192.168.1.100:8765'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
  });
}
