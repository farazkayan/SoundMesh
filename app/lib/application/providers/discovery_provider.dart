// Discovery platform providers.

import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_platform.dart';
import 'package:soundmesh/infrastructure/discovery/mock_discovery_platform.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';

/// Provider for the discovery platform implementation.
/// Uses mock implementation by default; overridden with real implementation on Android.
final discoveryPlatformProvider = Provider<DiscoveryPlatform>((ref) {
  // Use real MethodChannel implementation on Android, mock elsewhere (tests, desktop, etc.)
  if (Platform.isAndroid) {
    return MethodChannelDiscoveryPlatform();
  }
  return MockDiscoveryPlatform();
});

/// Provider for the DiscoveryManager.
final discoveryManagerProvider = Provider<DiscoveryManager>((ref) {
  final platform = ref.watch(discoveryPlatformProvider);
  return DiscoveryManager(
    platform: platform,
  );
});