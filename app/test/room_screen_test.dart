import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';
import 'package:soundmesh/infrastructure/discovery/mock_discovery_platform.dart';
import 'package:soundmesh/presentation/screens/room_screen.dart';
import 'package:soundmesh/presentation/screens/room_dashboard_screen.dart';

class MockNetworkRepository extends NetworkRepository {
  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      const Stream.empty();

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  Stream<RoomLifecycleState> get roomLifecycleStateStream =>
      const Stream.empty();

  @override
  NetworkConnectionState get currentState => NetworkConnectionState.disconnected;

  @override
  RoomLifecycleState get roomLifecycleState => RoomLifecycleState.created;

  @override
  RoomRole get roomRole => RoomRole.host;
}

class MockDiscoveryManager extends DiscoveryManager {
  MockDiscoveryManager() : super(platform: MockDiscoveryPlatform());

  @override
  HostDiscoveryService get hostService => MockHostDiscoveryService();
}

class MockHostDiscoveryService extends HostDiscoveryService {
  MockHostDiscoveryService() : super(platform: MockDiscoveryPlatform());

  @override
  Future<bool> startBroadcast({
    required String code,
    required String roomId,
    required int port,
    String? hostName,
  }) async {
    return true;
  }
}

class MockCreateRoomFlowNotifier extends CreateRoomFlowNotifier {
  MockCreateRoomFlowNotifier(CreateRoomFlowState state)
      : super(MockNetworkRepository(), MockDiscoveryManager()) {
    this.state = state;
  }
}

class MockJoinRoomFlowNotifier extends JoinRoomFlowNotifier {
  MockJoinRoomFlowNotifier(JoinRoomFlowState state)
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

class MockRoomScreenNotifier extends RoomScreenNotifier {
  MockRoomScreenNotifier(RoomScreenState state, NetworkRepository networkRepo, RoomLifecycleNotifier roomLifecycleNotifier)
      : super(networkRepo, roomLifecycleNotifier) {
    this.state = state;
  }
}

void main() {
  group('RoomDashboardScreen host widget tests', () {
    testWidgets('shows the room identity with host info', (
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
            roomScreenProvider.overrideWith(
              (_) => MockRoomScreenNotifier(
                const RoomScreenState(
                  connectionState: NetworkConnectionState.ready,
                  roomLifecycleState: RoomLifecycleState.ready,
                  roomRole: RoomRole.host,
                ),
                MockNetworkRepository(),
                MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
              ),
            ),
          ],
          child: const MaterialApp(home: RoomDashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Room'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
    });

    testWidgets('shows synchronized status when ready', (
      WidgetTester tester,
    ) async {
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
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
            ),
            roomScreenProvider.overrideWith(
              (_) => MockRoomScreenNotifier(
                const RoomScreenState(
                  connectionState: NetworkConnectionState.ready,
                  roomLifecycleState: RoomLifecycleState.ready,
                  roomRole: RoomRole.host,
                ),
                MockNetworkRepository(),
                MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
              ),
            ),
          ],
          child: const MaterialApp(home: RoomDashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Synchronized'), findsOneWidget);
      expect(find.text('Devices Synchronized'), findsOneWidget);
    });

    testWidgets('shows preparing state when handshaking', (
      WidgetTester tester,
    ) async {
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
              (_) => MockCreateRoomFlowNotifier(
                const CreateRoomFlowState(
                  status: CreateRoomFlowStatus.handshaking,
                ),
              ),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
            ),
            roomScreenProvider.overrideWith(
              (_) => MockRoomScreenNotifier(
                const RoomScreenState(
                  connectionState: NetworkConnectionState.ready,
                  roomLifecycleState: RoomLifecycleState.ready,
                  roomRole: RoomRole.host,
                ),
                MockNetworkRepository(),
                MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
              ),
            ),
          ],
          child: const MaterialApp(home: RoomDashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Preparing session…'), findsOneWidget);
    });

    testWidgets('shows error state when create room fails', (
      WidgetTester tester,
    ) async {
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
              (_) => MockCreateRoomFlowNotifier(
                const CreateRoomFlowState(
                  status: CreateRoomFlowStatus.failed,
                  errorMessage: 'Failed to create room',
                ),
              ),
            ),
            roomLifecycleProvider.overrideWith(
              (_) => MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
            ),
            roomScreenProvider.overrideWith(
              (_) => MockRoomScreenNotifier(
                const RoomScreenState(
                  connectionState: NetworkConnectionState.ready,
                  roomLifecycleState: RoomLifecycleState.ready,
                  roomRole: RoomRole.host,
                  errorMessage: 'Failed to create room',
                ),
                MockNetworkRepository(),
                MockRoomLifecycleNotifier(lifecycleState, MockNetworkRepository()),
              ),
            ),
          ],
          child: const MaterialApp(home: RoomDashboardScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Room Error'), findsOneWidget);
      expect(find.text('Failed to create room'), findsOneWidget);
    });
  });
}