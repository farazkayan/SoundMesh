import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/screens/home_screen.dart';
import 'package:soundmesh/presentation/screens/create_room_screen.dart';

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

      expect(find.widgetWithText(SMButton, 'Create Room'), findsOneWidget);
      expect(find.widgetWithText(SMButton, 'Join Room'), findsOneWidget);
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

      await tester.tap(find.widgetWithText(SMButton, 'Create Room'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateRoomScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Create Room'), findsAtLeastNWidgets(1));
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
      expect(find.text('Make your phones one speaker.'), findsOneWidget);
    });
  });
}