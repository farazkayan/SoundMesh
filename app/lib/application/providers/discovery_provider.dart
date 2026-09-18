// Discovery platform providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_platform.dart';
import 'package:soundmesh/infrastructure/discovery/mock_discovery_platform.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';
import 'package:soundmesh/presentation/state_compat.dart';

/// Provider for the discovery platform implementation.
/// Uses mock implementation by default; can be overridden for testing.
final discoveryPlatformProvider = Provider<DiscoveryPlatform>((ref) {
  return MockDiscoveryPlatform();
});

/// Provider for the CoreStateController (wired via StateProvider widget).
final coreStateControllerProvider = Provider<CoreStateController>((ref) {
  // This will be overridden by the StateProvider widget in main.dart
  throw UnimplementedError('coreStateControllerProvider must be overridden by StateProvider widget');
});

/// Provider for the DiscoveryManager.
final discoveryManagerProvider = Provider<DiscoveryManager>((ref) {
  final platform = ref.watch(discoveryPlatformProvider);
  return DiscoveryManager(
    platform: platform,
  );
});