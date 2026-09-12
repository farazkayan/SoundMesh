import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/screens/create_room_screen.dart';

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

class MockCreateRoomFlowNotifier extends CreateRoomFlowNotifier {
  MockCreateRoomFlowNotifier(CreateRoomFlowState state)
    : super(MockNetworkRepository()) {
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
            networkRepositoryProvider.overrideWithValue(
              MockNetworkRepository(),
            ),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create Room'),
        findsOneWidget,
      );
    });

    testWidgets('entering text updates the input field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(
              MockNetworkRepository(),
            ),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Room');
      await tester.pump();

      expect(find.text('Test Room'), findsOneWidget);
    });

    testWidgets('empty room name shows error on create attempt', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(
              MockNetworkRepository(),
            ),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      await tester.pump();

      expect(find.text('Please enter a room name'), findsOneWidget);
    });

    testWidgets('rapid double-tap starts hosting once without disconnecting', (
      WidgetTester tester,
    ) async {
      final repository = MockNetworkRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [networkRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Room');
      repository.startHoldingLocalIpLookup();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      repository.completeLocalIpLookup();
      await tester.pump();
      await tester.pump();

      expect(repository.startHostingCalls, 1);
      expect(repository.disconnectCalls, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows hosting indicator when creating room', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(
              MockNetworkRepository(),
            ),
          ],
          child: const MaterialApp(home: CreateRoomScreen()),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Room');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
            networkRepositoryProvider.overrideWithValue(
              MockNetworkRepository(),
            ),
            createRoomFlowProvider.overrideWith(
              (_) => MockCreateRoomFlowNotifier(
                const CreateRoomFlowState(
                  status: CreateRoomFlowStatus.hosted,
                  localIpAddress: '192.168.1.100',
                  port: 8765,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: const CreateRoomScreen(),
            routes: <String, WidgetBuilder>{
              AppRouter.room: (_) => const Scaffold(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
