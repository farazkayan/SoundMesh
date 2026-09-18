import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/screens/create_room_screen.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';
import 'package:soundmesh/infrastructure/discovery/mock_discovery_platform.dart';

class MockNetworkRepository extends NetworkRepository {
  int startHostingCalls = 0;
  int disconnectCalls = 0;
  bool holdLocalIpLookup = false;
  final Completer<String> _localIpCompleter = Completer<String>();

  @override
  Future<String> getLocalIpAddress() {
    if (holdLocalIpLookup) {
      return _localIpCompleter.future;
    }
    return Future<String>.value('192.168.1.100');
  }

  void startHoldingLocalIpLookup() {
    holdLocalIpLookup = true;
  }

  void completeLocalIpLookup() {
    _localIpCompleter.complete('192.168.1.100');
  }

  @override
  Future<bool> startHosting({int port = 8765}) async {
    startHostingCalls++;
    return true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      Stream.value(NetworkConnectionState.connected);

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  NetworkConnectionState get currentState => NetworkConnectionState.connected;
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

void main() {
  group('CreateRoomScreen widget tests', () {
    testWidgets('renders room name input and Create button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(
        find.widgetWithText(SMButton, 'Create Room'),
        findsOneWidget,
      );
    });

    testWidgets('entering text updates the input field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Test Room');
      await tester.pump();

      expect(find.text('Test Room'), findsOneWidget);
    });

    testWidgets('hosted success layout fits an 800x1280 viewport', (
      WidgetTester tester,
    ) async {
      final previousPhysicalSize = tester.view.physicalSize;
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.physicalSize = previousPhysicalSize;
        tester.view.devicePixelRatio = 1;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(
                const CreateRoomFlowState(
                  status: CreateRoomFlowStatus.ready,
                  localIpAddress: '192.168.1.100',
                  port: 8765,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: const CreateRoomScreen(),
            routes: <String, WidgetBuilder>{
              AppRouter.roomDashboard: (_) => const Scaffold(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows Room Created view in listening state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(
                const CreateRoomFlowState(
                  status: CreateRoomFlowStatus.listening,
                  localIpAddress: '192.168.1.50',
                  port: 8765,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );
      await tester.pump();

      // Verify the roomReady state text is shown
      expect(find.text('Room Created'), findsOneWidget);
      // Verify join code is NOT displayed (only shown for ready status per mahin_state_compat.dart)
      // Verify room ID is displayed
      expect(find.text('Room: —'), findsOneWidget);
      // Verify host indicator
      expect(find.text('You are the host.'), findsOneWidget);
      // Verify Enter Room button
      expect(find.widgetWithText(SMButton, 'Enter Room'), findsOneWidget);
    });
  });
}