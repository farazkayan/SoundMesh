import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/presentation/screens/room_screen.dart';

class MockNetworkRepository extends NetworkRepository {
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
  group('RoomScreen host widget tests', () {
    testWidgets('shows the host address with a copy action', (
      WidgetTester tester,
    ) async {
      const hostState = CreateRoomFlowState(
        status: CreateRoomFlowStatus.ready,
        localIpAddress: '192.168.1.100',
        port: 8765,
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
