import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'core/theme/soundmesh_theme.dart';
import 'core/router/app_router.dart';

/// Global navigator key for accessing context from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Defer Purchases SDK initialization until after first frame to avoid blocking startup.
  // RevenueCat is not required for the core SoundMesh experience.
  Future<void>.delayed(Duration.zero, () async {
    await Purchases.configure(
      PurchasesConfiguration('test_EZNJoVDMTpwEdwfMiMuMzEICOHt'),
    );
  });

  runApp(
    const ProviderScope(
      child: SoundMeshApp(),
    ),
  );
}

class SoundMeshApp extends ConsumerWidget {
  const SoundMeshApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: MaterialApp(
        title: 'SoundMesh',
        debugShowCheckedModeBanner: false,
        theme: SoundMeshTheme.darkTheme,
        navigatorKey: navigatorKey,
        initialRoute: AppRouter.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}

