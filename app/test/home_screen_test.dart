import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/screens/home_screen.dart';

void main() {
  group('HomeScreen widget tests', () {
    testWidgets('renders Create Room and Join Room buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.widgetWithText(ElevatedButton, 'Create Room'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Join Room'), findsOneWidget);
    });

    testWidgets('tapping Create Room navigates to create room route',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            initialRoute: AppRouter.home,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Room Name'), findsOneWidget);
    });

    testWidgets('tapping Join Room navigates to join room route',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            initialRoute: AppRouter.home,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Join Room'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Host Address'), findsOneWidget);
    });

    testWidgets('renders SoundMesh branding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      expect(find.text('SoundMesh'), findsOneWidget);
      expect(find.text('Synchronized audio, multiple devices'),
          findsOneWidget);
    });
  });
}
