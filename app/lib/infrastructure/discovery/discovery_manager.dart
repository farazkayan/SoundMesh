// Discovery service that orchestrates room code broadcast and scanning.

import 'dart:async';

import 'discovery_platform.dart';
import 'discovery_types.dart';
import 'join_payload.dart';
import 'dart:developer' as developer;

/// Service managing host-side room announcement broadcasting.
class HostDiscoveryService {
  HostDiscoveryService({
    required this._platform,
  });

  final DiscoveryPlatform _platform;
  
  bool _isBroadcasting = false;
  Timer? _expiryTimer;

  bool get isBroadcasting => _isBroadcasting;

  /// Starts broadcasting the room code on the local network.
  ///
  /// [expiresAt] is the join credential's expiration (per the bootstrap
  /// contract, DOCS/networking.md "Join Payload Contract"). When provided,
  /// it is embedded in the announcement payload and broadcasting stops
  /// automatically when the credential expires, so an expired code can no
  /// longer be resolved by new participants.
  Future<bool> startBroadcast({
    required String code,
    required String roomId,
    required int port,
    String? hostName,
    DateTime? expiresAt,
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
      expiresAt: expiresAt,
    );
    developer.log(
      'HostDiscoveryService: Platform startBroadcast returned: ${result.success} (error: ${result.errorMessage})',
      name: 'SoundMesh.HostDiscovery',
    );

    _isBroadcasting = result.success;
    _scheduleExpiryStop(expiresAt);
    return result.success;
  }

  /// Stops the broadcast when the join credential expires so the code is
  /// genuinely short-lived on the discovery path.
  void _scheduleExpiryStop(DateTime? expiresAt) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (expiresAt == null || !_isBroadcasting) return;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      stopBroadcast();
      return;
    }
    _expiryTimer = Timer(remaining, () {
      developer.log(
        'HostDiscoveryService: Join credential expired, stopping broadcast',
        name: 'SoundMesh.HostDiscovery',
      );
      stopBroadcast();
    });
  }

  /// Stops broadcasting the room code.
  Future<void> stopBroadcast() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
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
  ///
  /// Returns the RoomAnnouncement if found, null when the scan times out
  /// without finding the code (the bootstrap taxonomy's CODE_NOT_FOUND case).
  /// Throws [JoinPayloadException] with [JoinPayloadErrorCode.invalidPayload]
  /// for a malformed code.
  Future<RoomAnnouncement?> scanForRoom(String code) async {
    developer.log(
      '[JOIN_TRACE] ParticipantDiscoveryService: scanForRoom ENTERED for code: $code',
      name: 'SoundMesh.ParticipantDiscovery',
    );
    if (!isValidRoomCode(code)) {
      throw const JoinPayloadException(
        JoinPayloadErrorCode.invalidPayload,
        'Invalid room code format (expected 6 digits)',
      );
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
          // Found matching code! Ignore it if the credential has already
          // expired (beyond the clock-skew allowance) — an expired code must
          // not resolve to a joinable room.
          if (event.announcement.isExpiredAt(DateTime.now())) {
            developer.log(
              '[JOIN_TRACE] ParticipantDiscoveryService: Ignoring expired announcement for code: $code',
              name: 'SoundMesh.ParticipantDiscovery',
            );
            return;
          }
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

  /// Starts broadcasting a short-lived join credential for a room.
  /// Returns the issued code if successful, null otherwise.
  ///
  /// The actual room creation is done by createRoomFlowProvider.
  /// This method assumes the room already exists and just starts broadcasting.
  /// The credential is short-lived per the bootstrap contract
  /// (DOCS/networking.md, "Join Payload Contract").
  Future<String?> createAndBroadcastRoom({
    required String roomId,
    required int controlPort,
    String? hostName,
  }) async {
    final code = generateRoomCode();
    final expiresAt = DateTime.now().add(kJoinCodeLifetime);
    final broadcastSuccess = await _hostService.startBroadcast(
      code: code,
      roomId: roomId,
      port: controlPort,
      hostName: hostName,
      expiresAt: expiresAt,
    );
    
    if (!broadcastSuccess) {
      // Broadcast failed but room created - log warning
      // Room is still joinable via manual IP/port
      return null;
    }
    
    return code;
  }

  /// Joins a room by scanning for its code.
  /// Returns the RoomAnnouncement if found, null on timeout/error.
  Future<RoomAnnouncement?> joinRoomByCode({
    required String code,
    required int controlPort,
  }) async {
    // Scan for the room announcement
    final announcement = await _participantService.scanForRoom(code);
    
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