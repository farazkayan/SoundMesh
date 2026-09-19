// Unit tests for participant-side discovery validation under the
// formalized bootstrap contract: structured errors for malformed codes,
// CODE_NOT_FOUND mapping for scan timeout, and expired-announcement handling.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/infrastructure/discovery/join_payload.dart';
import 'package:soundmesh/infrastructure/discovery/mock_discovery_platform.dart';

/// Mock platform with a controllable scan stream so tests can inject
/// arbitrary announcement events (expired, non-matching, timeout).
class ControlledDiscoveryPlatform extends MockDiscoveryPlatform {
  final _controller = StreamController<DiscoveryEvent>.broadcast();

  @override
  Stream<DiscoveryEvent> startScan({
    required String code,
    int timeoutSeconds = kDiscoveryScanTimeoutSeconds,
  }) async* {
    yield* _controller.stream;
  }

  void emit(DiscoveryEvent event) => _controller.add(event);

  @override
  Future<void> stopScan() async {}
}

void main() {
  group('ParticipantDiscoveryService validation', () {
    test('scanForRoom throws structured INVALID_PAYLOAD for malformed code',
        () async {
      final service = ParticipantDiscoveryService(
        platform: MockDiscoveryPlatform(),
      );

      for (final badCode in ['12345', '1234567', 'abcdef', '12-456', '']) {
        expect(
          () => service.scanForRoom(badCode),
          throwsA(
            isA<JoinPayloadException>().having(
              (e) => e.code,
              'code',
              JoinPayloadErrorCode.invalidPayload,
            ),
          ),
          reason: 'code "$badCode" must be rejected with INVALID_PAYLOAD',
        );
      }
    });

    test('scanForRoom returns null on scan timeout (CODE_NOT_FOUND case)',
        () async {
      final service = ParticipantDiscoveryService(
        platform: MockDiscoveryPlatform(),
      );

      // MockDiscoveryPlatform emits a timeout event after 2s when no
      // announcement matches the requested code ('000000' never matches).
      final result = await service.scanForRoom('000000');

      expect(result, isNull,
          reason: 'scan timeout must surface as null, the CODE_NOT_FOUND case');
    });

    test('scanForRoom finds a live announcement', () async {
      final service = ParticipantDiscoveryService(
        platform: MockDiscoveryPlatform(),
      );

      final result = await service.scanForRoom('123456');

      expect(result, isNotNull);
      expect(result!.code, equals('123456'));
      expect(result.hostIp, equals('192.168.1.100'));
      expect(result.hostPort, equals(8080));
      // The mock behaves like a live host: fresh, non-expired credential.
      expect(result.isExpiredAt(DateTime.now()), isFalse);
    });

    test('scanForRoom ignores an expired announcement for the requested code',
        () async {
      final platform = ControlledDiscoveryPlatform();
      final service = ParticipantDiscoveryService(platform: platform);

      final futureResult = service.scanForRoom('123456');
      // Give the stream subscription a moment to attach, then push an expired
      // announcement (beyond the 60s clock-skew allowance) followed by the
      // scan timeout: the scan must ignore the expired credential and time
      // out rather than resolve to a joinable room.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      platform.emit(DiscoveryEvent(
        announcement: RoomAnnouncement(
          code: '123456',
          hostIp: '192.168.1.100',
          hostPort: 8080,
          protocolVersion: kDiscoveryProtocolVersion,
          roomId: 'room-test-001',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ));
      platform.emit(const DiscoveryEvent(
        announcement: RoomAnnouncement(
          code: '',
          hostIp: '',
          hostPort: 0,
          protocolVersion: 0,
          roomId: '',
        ),
        isTimeout: true,
      ));

      final result = await futureResult;
      expect(result, isNull,
          reason: 'an expired credential must not resolve to a joinable room');
    });

    test('scanForRoom ignores non-matching codes and keeps scanning', () async {
      final platform = ControlledDiscoveryPlatform();
      final service = ParticipantDiscoveryService(platform: platform);

      final futureResult = service.scanForRoom('123456');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      platform.emit(DiscoveryEvent(
        announcement: RoomAnnouncement(
          code: '654321',
          hostIp: '192.168.1.100',
          hostPort: 8080,
          protocolVersion: kDiscoveryProtocolVersion,
          roomId: 'room-test-001',
        ),
      ));
      platform.emit(DiscoveryEvent(
        announcement: RoomAnnouncement(
          code: '123456',
          hostIp: '192.168.1.100',
          hostPort: 8080,
          protocolVersion: kDiscoveryProtocolVersion,
          roomId: 'room-test-001',
        ),
      ));

      final result = await futureResult;
      expect(result, isNotNull);
      expect(result!.code, equals('123456'));
    });
  });
}
