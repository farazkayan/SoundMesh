import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'core/theme/soundmesh_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/state_compat.dart';
import 'application/providers/discovery_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Purchases.configure(
    PurchasesConfiguration('test_EZNJoVDMTpwEdwfMiMuMzEICOHt'),
  );

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
    final controller = CoreStateController(ref);
    return ProviderScope(
      overrides: [
        coreStateControllerProvider.overrideWithValue(controller),
      ],
      child: StateProvider(
        controller: controller,
        child: MaterialApp(
          title: 'SoundMesh',
          debugShowCheckedModeBanner: false,
          theme: SoundMeshTheme.darkTheme,
          initialRoute: AppRouter.home,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}
