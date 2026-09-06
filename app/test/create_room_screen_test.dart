import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/presentation/screens/create_room_screen.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';

class MockNetworkRepository extends NetworkRepository {
  @override
  Future<String> getLocalIpAddress() async => '192.168.1.100';

  @override
  Future<bool> startHosting({int port = 8765}) async => true;

  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      Stream.value(NetworkConnectionState.connected);

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  NetworkConnectionState get currentState => NetworkConnectionState.connected;
}

void main() {
  group('CreateRoomScreen widget tests', () {
    testWidgets('renders room name input and Create button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: CreateRoomScreen(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Create Room'), findsOneWidget);
    });

    testWidgets('entering text updates the input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: CreateRoomScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Room');
      await tester.pump();

      expect(find.text('Test Room'), findsOneWidget);
    });

    testWidgets('empty room name shows error on create attempt',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: CreateRoomScreen(),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      await tester.pump();

      expect(find.text('Please enter a room name'), findsOneWidget);
    });

    testWidgets('shows hosting indicator when creating room',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: CreateRoomScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test Room');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
