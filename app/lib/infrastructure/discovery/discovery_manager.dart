// Discovery service that orchestrates room code broadcast and scanning.
// Integrates with the main project's CoreStateController (via state_compat.dart).

import 'dart:async';

import 'package:soundmesh/presentation/state_compat.dart';
import 'discovery_platform.dart';
import 'discovery_types.dart';
import 'dart:developer' as developer;

/// Service managing host-side room announcement broadcasting.
class HostDiscoveryService {
  HostDiscoveryService({
    required this._platform,
  });

  final DiscoveryPlatform _platform;
  
  bool _isBroadcasting = false;

  bool get isBroadcasting => _isBroadcasting;

  /// Starts broadcasting the room code on the local network.
  Future<bool> startBroadcast({
    required String code,
    required String roomId,
    required int port,
    String? hostName,
  }) async {
    developer.log(
      '[JOIN_TRACE] HostDiscoveryService: startBroadcast called for code: $code, roomId: $roomId, port: $port',
      name: 'SoundMesh.HostDiscovery',
    );
    if (_isBroadcasting) {
      await stopBroadcast();
    }

    final ipAddress = await _platform.getLocalIpAddress();
    developer.log(
      'HostDiscoveryService: Got local IP for broadcast: $ipAddress',
      name: 'SoundMesh.HostDiscovery',
    );
    if (ipAddress == null) {
      developer.log(
        'HostDiscoveryService: No local IP available, cannot broadcast',
        name: 'SoundMesh.HostDiscovery',
      );
      return false;
    }

    final result = await _platform.startBroadcast(
      code: code,
      hostIp: ipAddress,
      hostPort: port,
      roomId: roomId,
      hostName: hostName,
    );
    developer.log(
      'HostDiscoveryService: Platform startBroadcast returned: ${result.success} (error: ${result.errorMessage})',
      name: 'SoundMesh.HostDiscovery',
    );

    _isBroadcasting = result.success;
    return result.success;
  }

  /// Stops broadcasting the room code.
  Future<void> stopBroadcast() async {
    if (!_isBroadcasting) return;

    await _platform.stopBroadcast();
    _isBroadcasting = false;
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await stopBroadcast();
  }
}

/// Service managing participant-side room code scanning.
class ParticipantDiscoveryService {
  ParticipantDiscoveryService({
    required this._platform,
  });

  final DiscoveryPlatform _platform;
  
  StreamSubscription<DiscoveryEvent>? _scanSubscription;
  bool _isScanning = false;
  Completer<RoomAnnouncement?>? _scanCompleter;

  bool get isScanning => _isScanning;

  /// Scans for a room with the given 6-digit code.
  /// Returns the RoomAnnouncement if found, null on timeout/error.
  Future<RoomAnnouncement?> scanForRoom(String code) async {
    developer.log(
      '[JOIN_TRACE] ParticipantDiscoveryService: scanForRoom ENTERED for code: $code',
      name: 'SoundMesh.ParticipantDiscovery',
    );
    if (!isValidRoomCode(code)) {
      throw ArgumentError('Invalid room code format: $code');
    }

    if (_isScanning) {
      await stopScan();
    }

    _isScanning = true;
    _scanCompleter = Completer<RoomAnnouncement?>();

    developer.log(
      '[JOIN_TRACE] ParticipantDiscoveryService: Calling platform.startScan()',
      name: 'SoundMesh.ParticipantDiscovery',
    );

    final stream = _platform.startScan(code: code);
    
    _scanSubscription = stream.listen(
      (event) {
        if (event.isTimeout) {
          developer.log(
            '[JOIN_TRACE] ParticipantDiscoveryService: TIMEOUT received',
            name: 'SoundMesh.ParticipantDiscovery',
          );
          if (_scanCompleter != null && !_scanCompleter!.isCompleted) {
            _scanCompleter!.complete(null);
          }
          _isScanning = false;
        } else if (event.announcement.code == code) {
          // Found matching room!
          developer.log(
            '[JOIN_TRACE] ParticipantDiscoveryService: MATCH FOUND for code: $code',
            name: 'SoundMesh.ParticipantDiscovery',
          );
          if (_scanCompleter != null && !_scanCompleter!.isCompleted) {
            _scanCompleter!.complete(event.announcement);
          }
          _isScanning = false;
        }
        // Ignore non-matching codes
      },
      onError: (error) {
        developer.log(
          '[JOIN_TRACE] ParticipantDiscoveryService: ERROR in stream: $error',
          name: 'SoundMesh.ParticipantDiscovery',
        );
        if (_scanCompleter != null && !_scanCompleter!.isCompleted) {
          _scanCompleter!.completeError(error);
        }
        _isScanning = false;
      },
      onDone: () {
        developer.log(
          '[JOIN_TRACE] ParticipantDiscoveryService: Stream onDone (closed)',
          name: 'SoundMesh.ParticipantDiscovery',
        );
        if (_scanCompleter != null && !_scanCompleter!.isCompleted) {
          _scanCompleter!.complete(null);
        }
        _isScanning = false;
      },
    );

    try {
      final announcement = await _scanCompleter!.future;
      developer.log(
        '[JOIN_TRACE] ParticipantDiscoveryService: scanForRoom completed with: ${announcement != null ? "FOUND" : "NULL"}',
        name: 'SoundMesh.ParticipantDiscovery',
      );
      return announcement;
    } finally {
      await stopScan();
    }
  }

  /// Stops scanning for room announcements.
  Future<void> stopScan() async {
    if (!_isScanning) return;

    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _platform.stopScan();
    _isScanning = false;
    _scanCompleter = null;
  }

  /// Disposes resources.
  Future<void> dispose() async {
    await stopScan();
  }
}

/// Combined discovery manager for the application.
/// Can be used by Riverpod providers (createRoomFlowProvider, joinRoomFlowProvider).
class DiscoveryManager {
  DiscoveryManager({
    required DiscoveryPlatform platform,
  }) : _hostService = HostDiscoveryService(
          platform: platform,
        ),
        _participantService = ParticipantDiscoveryService(
          platform: platform,
        );

  final HostDiscoveryService _hostService;
  final ParticipantDiscoveryService _participantService;

  HostDiscoveryService get hostService => _hostService;
  ParticipantDiscoveryService get participantService => _participantService;

  /// Creates a room and starts broadcasting its code.
  /// Returns the join code if successful, null otherwise.
  Future<String?> createAndBroadcastRoom({
    required String roomId,
    required int controlPort,
    String? hostName,
  }) async {
    // The actual room creation is done by createRoomFlowProvider.
    // This method assumes the room already exists and just starts broadcasting.
    final broadcastSuccess = await _hostService.startBroadcast(
      code: generateRoomCode(),
      roomId: roomId,
      port: controlPort,
      hostName: hostName,
    );
    
    if (!broadcastSuccess) {
      // Broadcast failed but room created - log warning
      // Room is still joinable via manual IP/port
      return null;
    }
    
    // Return the generated code (in real implementation, this would come from the provider)
    return null; // The provider manages the actual code
  }

  /// Joins a room by scanning for its code.
  /// Returns the RoomAnnouncement if found, null on timeout/error.
  Future<RoomAnnouncement?> joinRoomByCode({
    required String code,
    required int controlPort,
    required CoreStateController controller,
  }) async {
    // Scan for the room announcement
    final announcement = await _participantService.scanForRoom(code);
    
    if (announcement == null) {
      // Discovery failed - return null to indicate not found
      await controller.transitionTo(SMAppState.error);
      return null;
    }

    // The actual join is done by joinRoomFlowProvider using the discovered IP/port
    // This method just returns the announcement for the provider to use
    return announcement;
  }

  /// Stops all discovery operations.
  Future<void> stopAll() async {
    await _hostService.stopBroadcast();
    await _participantService.stopScan();
  }

  /// Disposes all resources.
  Future<void> dispose() async {
    await stopAll();
    await _hostService.dispose();
    await _participantService.dispose();
  }
}