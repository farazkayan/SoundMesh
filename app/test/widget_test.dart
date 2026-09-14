import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/repositories/device_info_repository.dart';
import 'package:soundmesh/application/repositories/timing_info_repository.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/presentation/screens/home_screen.dart';
import 'package:soundmesh/presentation/screens/create_room_screen.dart';
import 'package:soundmesh/presentation/screens/join_room_screen.dart';
import 'package:soundmesh/presentation/screens/room_screen.dart';
import 'package:soundmesh/presentation/screens/settings_screen.dart';
import 'package:soundmesh/presentation/screens/diagnostics_screen.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';

void main() {
  group('Screen smoke tests', () {
    testWidgets('HomeScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomeScreen()),
        ),
      );
      expect(find.text('SoundMesh'), findsOneWidget);
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
      expect(find.text('Join Room'), findsAtLeastNWidgets(1));
    });

    testWidgets('RoomScreen smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            networkRepositoryProvider.overrideWithValue(MockNetworkRepository()),
          ],
          child: const MaterialApp(
            home: RoomScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RoomScreen), findsOneWidget);
    });

    testWidgets('SettingsScreen renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SettingsScreen()),
        ),
      );
      expect(find.text('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('DiagnosticsScreen smoke test', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(
              deviceRepositoryBuilder: () => _FakeSuccessRepository(),
              timingRepositoryBuilder: () => _FakeTimingRepository(initialNanos: 1000000000),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Native Bridge Active'), findsOneWidget);
    });
  });

  group('DiagnosticsScreen platform integration', () {
    testWidgets('shows device info on success', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(
              deviceRepositoryBuilder: () => _FakeSuccessRepository(),
              timingRepositoryBuilder: () => _FakeTimingRepository(initialNanos: 1000000000),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Native Bridge Active'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Pixel 7'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Monotonic Timing'), findsOneWidget);
    });

    testWidgets('shows error state on platform exception',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(
              deviceRepositoryBuilder: () => _FakeErrorRepository(),
              timingRepositoryBuilder: () => _FakeTimingRepository(initialNanos: 1000000000),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Platform Error'), findsOneWidget);
      expect(find.text('UNAVAILABLE: Platform channel not available'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('retry button refetches device info',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(
              deviceRepositoryBuilder: () => _FakeCallCountRepository(),
              timingRepositoryBuilder: () => _FakeTimingRepository(initialNanos: 1000000000),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Platform Error'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Native Bridge Active'), findsOneWidget);
      expect(find.text('iOS'), findsOneWidget);
    });

    testWidgets('shows increasing monotonic time on successive reads',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(
              deviceRepositoryBuilder: () => _FakeSuccessRepository(),
              timingRepositoryBuilder: () => _FakeIncreasingTimingRepository(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Monotonic Timing'), findsOneWidget);
      expect(find.text('Increasing (monotonic)'), findsOneWidget);

      await tester.tap(find.text('Read Again'));
      await tester.pumpAndSettle();

      expect(find.text('Increasing (monotonic)'), findsOneWidget);
    });

    testWidgets('shows error when timing repository throws',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiagnosticsScreen(
              deviceRepositoryBuilder: () => _FakeSuccessRepository(),
              timingRepositoryBuilder: () => _FakeTimingErrorRepository(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Platform Error'), findsOneWidget);
      expect(find.text('TIMING_ERROR: Timing not available'), findsOneWidget);
    });
  });
}

class _FakeSuccessRepository implements DeviceInfoRepository {
  @override
  Future<DeviceInfo> getDeviceInfo() async {
    return DeviceInfo(
      platformName: 'Android',
      osVersion: '14',
      deviceModel: 'Pixel 7',
      brand: 'Google',
    );
  }
}

class _FakeErrorRepository implements DeviceInfoRepository {
  @override
  Future<DeviceInfo> getDeviceInfo() async {
    throw PlatformException(
      code: 'UNAVAILABLE',
      message: 'Platform channel not available',
    );
  }
}

class _FakeCallCountRepository implements DeviceInfoRepository {
  int _callCount = 0;

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    _callCount++;
    if (_callCount == 1) {
      throw PlatformException(
        code: 'ERROR',
        message: 'First call fails',
      );
    }
    return DeviceInfo(
      platformName: 'iOS',
      osVersion: '17.0',
      deviceModel: 'iPhone 15',
      brand: 'Apple',
    );
  }
}

class _FakeTimingRepository implements TimingInfoRepository {
  final int _initialNanos;

  _FakeTimingRepository({required this._initialNanos});

  @override
  Future<int> getMonotonicTimeNanos() async {
    return _initialNanos;
  }
}

class _FakeIncreasingTimingRepository implements TimingInfoRepository {
  int _callCount = 0;

  @override
  Future<int> getMonotonicTimeNanos() async {
    _callCount++;
    return 1000000000 + (_callCount * 1000000);
  }
}

class _FakeTimingErrorRepository implements TimingInfoRepository {
  @override
  Future<int> getMonotonicTimeNanos() async {
    throw PlatformException(
      code: 'TIMING_ERROR',
      message: 'Timing not available',
    );
  }
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
