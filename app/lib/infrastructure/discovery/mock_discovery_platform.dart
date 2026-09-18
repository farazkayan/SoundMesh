// Mock discovery platform for testing and non-Android platforms.

import 'dart:async';

import 'discovery_platform.dart';
import 'discovery_types.dart';

/// Mock implementation of DiscoveryPlatform for testing and development.
class MockDiscoveryPlatform extends DiscoveryPlatform {
  MockDiscoveryPlatform() {
    _initializeMockData();
  }

  final _scanController = StreamController<DiscoveryEvent>.broadcast();
  bool _isBroadcasting = false;
  bool _isScanning = false;
  Timer? _broadcastTimer;
  Timer? _scanTimer;
  String? _currentCode;
  RoomAnnouncement? _mockAnnouncement;

  void _initializeMockData() {
    // Create a mock announcement for testing
    _mockAnnouncement = RoomAnnouncement(
      code: '123456',
      hostIp: '192.168.1.100',
      hostPort: 8080,
      protocolVersion: kDiscoveryProtocolVersion,
      roomId: 'room-test-001',
      hostName: 'Test Host',
    );
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
    if (_isBroadcasting) {
      await stopBroadcast();
    }
    
    _isBroadcasting = true;
    _currentCode = code;
    
    // Simulate periodic broadcasts
    _broadcastTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) {
        if (_isBroadcasting && _mockAnnouncement != null) {
          // In a real implementation, this would send UDP broadcast
          // For mock, we just log
        }
      },
    );
    
    return const StartBroadcastResult(success: true);
  }

  @override
  Future<StopBroadcastResult> stopBroadcast() async {
    _isBroadcasting = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _currentCode = null;
    return const StopBroadcastResult(success: true);
  }

  @override
  Stream<DiscoveryEvent> startScan({
    required String code,
    int timeoutSeconds = kDiscoveryScanTimeoutSeconds,
  }) async* {
    if (_isScanning) {
      await stopScan();
    }
    _isScanning = true;

    // Simulate finding the room after a short delay
    _scanTimer = Timer(Duration(seconds: 2), () {
      if (_isScanning && _mockAnnouncement != null && _mockAnnouncement!.code == code) {
        _scanController.add(DiscoveryEvent(announcement: _mockAnnouncement!));
      } else if (_isScanning) {
        // Timeout - no matching room found
        _scanController.add(const DiscoveryEvent(
          announcement: RoomAnnouncement(
            code: '',
            hostIp: '',
            hostPort: 0,
            protocolVersion: 0,
            roomId: '',
          ),
          isTimeout: true,
        ));
      }
    });

    yield* _scanController.stream;
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
  }

  @override
  Future<String?> getLocalIpAddress() async {
    return '192.168.1.100';
  }

  @override
  Future<bool> hasLocalNetworkPermission() async {
    return true;
  }

  @override
  Future<bool> requestLocalNetworkPermission() async {
    return true;
  }

  void dispose() {
    _broadcastTimer?.cancel();
    _scanTimer?.cancel();
    _scanController.close();
  }
}