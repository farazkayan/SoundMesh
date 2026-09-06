import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/soundmesh_theme.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SoundMeshApp(),
    ),
  );
}

class SoundMeshApp extends StatelessWidget {
  const SoundMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundMesh',
      debugShowCheckedModeBanner: false,
      theme: SoundMeshTheme.darkTheme,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
