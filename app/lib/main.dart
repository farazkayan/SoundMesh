import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'core/theme/soundmesh_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/state_compat.dart';
import 'application/providers/discovery_provider.dart';

void main() {
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
