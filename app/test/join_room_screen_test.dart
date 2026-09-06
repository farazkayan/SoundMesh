import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/presentation/screens/join_room_screen.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';

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
    testWidgets('renders IP input, port input and Join button',
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

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'Join Room'), findsOneWidget);
    });

    testWidgets('renders Join Room title',
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

      expect(find.text('Join Room'), findsNWidgets(2));
    });
  });
}
