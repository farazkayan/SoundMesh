import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/presentation/screens/home_screen.dart';
import 'package:soundmesh/presentation/screens/create_room_screen.dart';
import 'package:soundmesh/presentation/screens/join_room_screen.dart';
import 'package:soundmesh/presentation/screens/room_dashboard_screen.dart';
import 'package:soundmesh/presentation/screens/settings_screen.dart';
import 'package:soundmesh/presentation/screens/diagnostics_screen.dart';

void main() {
  group('Screen smoke tests', () {
    testWidgets('HomeScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomeScreen()),
        ),
      );
      expect(find.text('SoundMesh'), findsOneWidget);
      expect(find.text('Make your phones one speaker.'), findsOneWidget);
    });

    testWidgets('CreateRoomScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CreateRoomScreen()),
        ),
      );
      expect(find.text('Create Room'), findsAtLeastNWidgets(1));
    });

    testWidgets('JoinRoomScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: JoinRoomScreen()),
        ),
      );
      expect(find.text('Connect to a Room'), findsOneWidget);
      expect(find.text('ROOM CODE'), findsOneWidget);
      expect(find.text('Join Room'), findsAtLeastNWidgets(1));
    });

    testWidgets('RoomDashboardScreen smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: RoomDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RoomDashboardScreen), findsOneWidget);
    });

    testWidgets('SettingsScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('DiagnosticsScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RoomDiagnosticsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Diagnostics'), findsAtLeastNWidgets(1));
    });
  });
}

class MockNetworkRepository extends NetworkRepository {
  @override
  Stream<NetworkConnectionState> get connectionStateStream =>
      Stream.value(NetworkConnectionState.connected);

  @override
  Stream<String> get messageStream => const Stream.empty();

  @override
  NetworkConnectionState get currentState => NetworkConnectionState.connected;
}