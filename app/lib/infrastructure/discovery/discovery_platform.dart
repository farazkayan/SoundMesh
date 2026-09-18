// Platform interface for native discovery operations.
// Implemented via Pigeon-generated platform channels.

import 'dart:async';

import 'discovery_types.dart';
import 'dart:developer' as developer;

/// Platform interface for discovery operations.
/// Native implementation handles UDP broadcast/multicast.
abstract class DiscoveryPlatform {
  /// Starts broadcasting room announcements on the local network.
  Future<StartBroadcastResult> startBroadcast({
    required String code,
    required String hostIp,
    required int hostPort,
    required String roomId,
    String? hostName,
    int intervalSeconds = kDiscoveryBroadcastIntervalSeconds,
  });

  /// Stops broadcasting room announcements.
  Future<StopBroadcastResult> stopBroadcast();

  /// Starts scanning for room announcements matching the given code.
  /// Returns a stream of discovered announcements.
  Stream<DiscoveryEvent> startScan({
    required String code,
    int timeoutSeconds = kDiscoveryScanTimeoutSeconds,
  });

  /// Stops scanning for room announcements.
  Future<void> stopScan();

  /// Gets the local IP address for broadcasting.
  Future<String?> getLocalIpAddress();

  /// Checks if local network permission is granted (Android 13+).
  Future<bool> hasLocalNetworkPermission();

  /// Requests local network permission (Android 13+).
  Future<bool> requestLocalNetworkPermission();
}

/// Method channel names for discovery.
class _DiscoveryMethodChannels {
  static const String scan = 'soundmesh/discovery_scan';
}

/// Default implementation using method channels (fallback before Pigeon).
class MethodChannelDiscoveryPlatform extends DiscoveryPlatform {
  final _scanController = StreamController<DiscoveryEvent>.broadcast();
  bool _isScanning = false;

  @override
  Future<StartBroadcastResult> startBroadcast({
    required String code,
    required String hostIp,
    required int hostPort,
    required String roomId,
    String? hostName,
    int intervalSeconds = kDiscoveryBroadcastIntervalSeconds,
  }) async {
    developer.log(
      'MethodChannelDiscoveryPlatform: startBroadcast called for code: $code (fallback - not implemented)',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    return StartBroadcastResult(success: false, errorMessage: 'Native implementation required');
  }

  @override
  Future<StopBroadcastResult> stopBroadcast() async {
    developer.log(
      'MethodChannelDiscoveryPlatform: stopBroadcast called',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    return const StopBroadcastResult(success: true);
  }

  @override
  Stream<DiscoveryEvent> startScan({
    required String code,
    int timeoutSeconds = kDiscoveryScanTimeoutSeconds,
  }) async* {
    developer.log(
      'MethodChannelDiscoveryPlatform: startScan called for code: $code (fallback - not implemented)',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    if (_isScanning) {
      await stopScan();
    }
    _isScanning = true;
    yield* _scanController.stream;
  }

  @override
  Future<void> stopScan() async {
    developer.log(
      'MethodChannelDiscoveryPlatform: stopScan called',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    _isScanning = false;
  }

  @override
  Future<String?> getLocalIpAddress() async {
    return null;
  }

  @override
  Future<bool> hasLocalNetworkPermission() async {
    return true;
  }

  @override
  Future<bool> requestLocalNetworkPermission() async {
    return true;
  }

  /// Handles incoming discovery events from native side.
  void handleDiscoveryEvent(DiscoveryEvent event) {
    developer.log(
      'MethodChannelDiscoveryPlatform: handleDiscoveryEvent: ${event.isTimeout ? "TIMEOUT" : "ANNOUNCEMENT(${event.announcement.code})"}',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    if (!_scanController.isClosed) {
      _scanController.add(event);
    }
  }

  void dispose() {
    _scanController.close();
  }
}