// Platform interface for native discovery operations.
// Implemented via Pigeon-generated platform channels.

import 'dart:async';

import 'discovery_types.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart' show MethodChannel, MethodCall;

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

/// Default implementation using method channels (fallback before Pigeon).
class MethodChannelDiscoveryPlatform extends DiscoveryPlatform {
  final _scanController = StreamController<DiscoveryEvent>.broadcast();
  bool _isScanning = false;
  final _methodChannel = const MethodChannel('soundmesh/discovery');

  MethodChannelDiscoveryPlatform() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDiscoveryEvent') {
      final args = call.arguments as Map<dynamic, dynamic>;
      final event = DiscoveryEvent(
        announcement: RoomAnnouncement(
          code: args['code'] as String,
          hostIp: args['host_ip'] as String,
          hostPort: args['host_port'] as int,
          protocolVersion: args['protocol_version'] as int,
          roomId: args['room_id'] as String,
          hostName: args['host_name'] as String?,
        ),
        isTimeout: args['is_timeout'] as bool,
      );
      developer.log(
        '[JOIN_TRACE] MethodChannelDiscoveryPlatform: Received onDiscoveryEvent from native: ${event.isTimeout ? "TIMEOUT" : "ANNOUNCEMENT(${event.announcement.code})"}',
        name: 'SoundMesh.DiscoveryPlatform',
      );
      if (!_scanController.isClosed) {
        _scanController.add(event);
      }
    }
  }

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
      '[JOIN_TRACE] MethodChannelDiscoveryPlatform: startBroadcast called for code: $code',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    final result = await _methodChannel.invokeMethod('startBroadcast', {
      'code': code,
      'hostIp': hostIp,
      'hostPort': hostPort,
      'roomId': roomId,
      'hostName': hostName,
      'intervalSeconds': intervalSeconds,
    });
    return StartBroadcastResult(success: result as bool, errorMessage: result == true ? null : 'Native call failed');
  }

  @override
  Future<StopBroadcastResult> stopBroadcast() async {
    developer.log(
      '[JOIN_TRACE] MethodChannelDiscoveryPlatform: stopBroadcast called',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    await _methodChannel.invokeMethod('stopBroadcast');
    return const StopBroadcastResult(success: true);
  }

  @override
  Stream<DiscoveryEvent> startScan({
    required String code,
    int timeoutSeconds = kDiscoveryScanTimeoutSeconds,
  }) async* {
    developer.log(
      '[JOIN_TRACE] MethodChannelDiscoveryPlatform: startScan called for code: $code',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    if (_isScanning) {
      await stopScan();
    }
    _isScanning = true;
    await _methodChannel.invokeMethod('startScan', {
      'code': code,
      'timeoutSeconds': timeoutSeconds,
    });
    yield* _scanController.stream;
  }

  @override
  Future<void> stopScan() async {
    developer.log(
      '[JOIN_TRACE] MethodChannelDiscoveryPlatform: stopScan called',
      name: 'SoundMesh.DiscoveryPlatform',
    );
    _isScanning = false;
    await _methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<String?> getLocalIpAddress() async {
    final result = await _methodChannel.invokeMethod('getLocalIpAddress');
    return result as String?;
  }

  @override
  Future<bool> hasLocalNetworkPermission() async {
    final result = await _methodChannel.invokeMethod('hasLocalNetworkPermission');
    return result as bool;
  }

  @override
  Future<bool> requestLocalNetworkPermission() async {
    final result = await _methodChannel.invokeMethod('requestLocalNetworkPermission');
    return result as bool;
  }

  void dispose() {
    _scanController.close();
  }
}