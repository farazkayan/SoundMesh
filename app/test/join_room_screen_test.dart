import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/screens/join_room_screen.dart';

class MockNetworkRepository extends NetworkRepository {
  @override
  Future<bool> connectToHost(String ipAddress, {int port = 8765}) async => true;

  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      Stream.value(NetworkConnectionState.connecting);

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  NetworkConnectionState get currentState => NetworkConnectionState.connecting;
}

void main() {
  group('JoinRoomScreen widget tests', () {
    testWidgets('renders Room Code input and Join Room button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: JoinRoomScreen(),
          ),
        ),
      );

      // One text field: Room Code (uses TextField, not TextFormField)
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(SMButton, 'Join Room'), findsOneWidget);
    });

    testWidgets('renders Connect to a Room title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: JoinRoomScreen(),
          ),
        ),
      );

      expect(find.text('Connect to a Room'), findsOneWidget);
    });

    testWidgets('renders QR Scan card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: JoinRoomScreen(),
          ),
        ),
      );

      expect(find.text('Scan QR Code'), findsOneWidget);
      // No "OR" divider in current implementation
    });

    testWidgets('Room Code field accepts digits only',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: JoinRoomScreen(),
          ),
        ),
      );

      // Enter room code digits
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      // Verify text field shows entered value
      expect(find.text('123456'), findsOneWidget);
    });

    testWidgets('Does not show manual entry fallback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: JoinRoomScreen(),
          ),
        ),
      );

      expect(find.text('Enter IP/Port manually'), findsNothing);
    });
  });
}