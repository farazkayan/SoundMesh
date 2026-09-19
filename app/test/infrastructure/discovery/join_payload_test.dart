// Unit tests for the transport-independent join payload contract:
// URI encoding/decoding, expiration boundaries, structured error taxonomy,
// and conversion to/from the UDP discovery announcement.

import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';
import 'package:soundmesh/infrastructure/discovery/join_payload.dart';

void main() {
  const roomId = 'room-6f1e2a3b';
  const hostAddress = '192.168.1.100';
  const hostPort = 8765;
  const code = '123456';
  final issuedAt = DateTime.parse('2026-09-19T12:00:00.000');

  JoinPayload validPayload({DateTime? expiresAt}) => JoinPayload(
        roomId: roomId,
        hostAddress: hostAddress,
        hostPort: hostPort,
        protocolVersion: kJoinPayloadProtocolVersion,
        code: code,
        expiresAt: expiresAt,
      );

  group('JoinPayload URI Encoding/Decoding', () {
    test('toJoinUri produces the DEC-013 URI format', () {
      final uri = validPayload().toJoinUri();

      expect(uri, startsWith('soundmesh://join?'));
      expect(uri, contains('room=room-6f1e2a3b'));
      expect(uri, contains('host=192.168.1.100'));
      expect(uri, contains('port=8765'));
      expect(uri, contains('version=1'));
      expect(uri, contains('token=123456'));
      // No expiration carried when the payload has none.
      expect(uri, isNot(contains('expires')));
    });

    test('toJoinUri includes expires when the payload carries expiration', () {
      final uri = validPayload(
        expiresAt: issuedAt.add(kJoinCodeLifetime),
      ).toJoinUri();

      expect(
        uri,
        contains(
          'expires=${issuedAt.add(kJoinCodeLifetime).millisecondsSinceEpoch}',
        ),
      );
    });

    test('parseJoinUri round-trips a URI with expiration', () {
      final original = JoinPayload(
        roomId: roomId,
        hostAddress: hostAddress,
        hostPort: hostPort,
        protocolVersion: kJoinPayloadProtocolVersion,
        code: code,
        issuedAt: issuedAt,
        expiresAt: issuedAt.add(kJoinCodeLifetime),
      );

      final decoded = JoinPayload.parseJoinUri(
        original.toJoinUri(),
        now: issuedAt,
      );

      expect(decoded.roomId, equals(roomId));
      expect(decoded.hostAddress, equals(hostAddress));
      expect(decoded.hostPort, equals(hostPort));
      expect(decoded.protocolVersion, equals(kJoinPayloadProtocolVersion));
      expect(decoded.code, equals(code));
      expect(decoded.expiresAt, equals(issuedAt.add(kJoinCodeLifetime)));
    });

    test('parseJoinUri round-trips a URI without expiration', () {
      final decoded = JoinPayload.parseJoinUri(validPayload().toJoinUri());

      expect(decoded.roomId, equals(roomId));
      expect(decoded.expiresAt, isNull);
    });

    test('parseJoinUri accepts code= as an alias for token=', () {
      final uri = 'soundmesh://join?room=$roomId&host=$hostAddress'
          '&port=$hostPort&version=1&code=$code';

      final decoded = JoinPayload.parseJoinUri(uri);

      expect(decoded.code, equals(code));
    });

    test('JoinPayload.issue sets issuedAt and expiresAt from lifetime', () {
      final payload = JoinPayload.issue(
        roomId: roomId,
        hostAddress: hostAddress,
        hostPort: hostPort,
        code: code,
        now: issuedAt,
      );

      expect(payload.issuedAt, equals(issuedAt));
      expect(payload.expiresAt, equals(issuedAt.add(kJoinCodeLifetime)));
    });

    test('kJoinCodeLifetime is the documented 10-minute default', () {
      expect(kJoinCodeLifetime, equals(const Duration(minutes: 10)));
    });
  });

  group('JoinPayload Expiration Validation', () {
    test('payload not yet expired passes validation', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final payload = validPayload(expiresAt: expiresAt);

      expect(payload.isExpiredAt(issuedAt), isFalse);
      expect(
        JoinPayload.parseJoinUri(
          payload.toJoinUri(),
          now: issuedAt.add(const Duration(minutes: 9)),
        ).code,
        equals(code),
      );
    });

    test('payload expired within the clock-skew allowance still passes', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final payload = validPayload(expiresAt: expiresAt);

      // Expired by 59 seconds — inside the 60s skew allowance.
      expect(
        payload.isExpiredAt(expiresAt.add(const Duration(seconds: 59))),
        isFalse,
      );
      expect(
        JoinPayload.parseJoinUri(
          payload.toJoinUri(),
          now: expiresAt.add(const Duration(seconds: 59)),
        ).code,
        equals(code),
      );
    });

    test('payload expired beyond the skew allowance raises CODE_EXPIRED', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final payload = validPayload(expiresAt: expiresAt);

      // Expired by 61 seconds — just beyond the 60s skew allowance.
      expect(
        payload.isExpiredAt(expiresAt.add(const Duration(seconds: 61))),
        isTrue,
      );
      expect(
        () => JoinPayload.parseJoinUri(
          payload.toJoinUri(),
          now: expiresAt.add(const Duration(seconds: 61)),
        ),
        throwsA(
          isA<JoinPayloadException>().having(
            (e) => e.code,
            'code',
            JoinPayloadErrorCode.codeExpired,
          ),
        ),
      );
    });

    test('expiration boundary at exactly the skew threshold passes', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final payload = validPayload(expiresAt: expiresAt);

      // isAfter(expiresAt + skew) — exactly at the threshold is not expired.
      expect(
        payload.isExpiredAt(expiresAt.add(kJoinExpiryClockSkewAllowance)),
        isFalse,
      );
    });

    test('payload without expiration never reports expired', () {
      expect(validPayload().isExpiredAt(issuedAt), isFalse);
    });

    test('expiration enforcement can be disabled for inspection', () {
      final expiresAt = issuedAt.subtract(const Duration(hours: 1));
      final payload = validPayload(expiresAt: expiresAt);

      final decoded = JoinPayload.parseJoinUri(
        payload.toJoinUri(),
        enforceExpiry: false,
      );

      expect(decoded.code, equals(code));
      expect(decoded.expiresAt, equals(expiresAt));
    });
  });

  group('JoinPayload Structured Errors', () {
    test('non-URI input raises INVALID_PAYLOAD', () {
      expect(
        () => JoinPayload.parseJoinUri('not a uri'),
        throwsA(
          isA<JoinPayloadException>().having(
            (e) => e.code,
            'code',
            JoinPayloadErrorCode.invalidPayload,
          ),
        ),
      );
    });

    test('wrong scheme raises INVALID_PAYLOAD', () {
      expect(
        () => JoinPayload.parseJoinUri(
          'https://join?room=$roomId&host=$hostAddress&port=$hostPort'
          '&version=1&token=$code',
        ),
        throwsA(
          isA<JoinPayloadException>().having(
            (e) => e.code,
            'code',
            JoinPayloadErrorCode.invalidPayload,
          ),
        ),
      );
    });

    test('missing required fields raises INVALID_PAYLOAD', () {
      expect(
        () => JoinPayload.parseJoinUri(
          'soundmesh://join?room=$roomId&host=$hostAddress&port=$hostPort'
          '&version=1',
        ),
        throwsA(
          isA<JoinPayloadException>().having(
            (e) => e.code,
            'code',
            JoinPayloadErrorCode.invalidPayload,
          ),
        ),
      );
    });

    test('invalid port raises INVALID_PAYLOAD', () {
      for (final badPort in ['0', '70000', 'abc']) {
        expect(
          () => JoinPayload.parseJoinUri(
            'soundmesh://join?room=$roomId&host=$hostAddress&port=$badPort'
            '&version=1&token=$code',
          ),
          throwsA(
            isA<JoinPayloadException>().having(
              (e) => e.code,
              'code',
              JoinPayloadErrorCode.invalidPayload,
            ),
          ),
          reason: 'port "$badPort" must be rejected',
        );
      }
    });

    test('malformed expiration raises INVALID_PAYLOAD', () {
      expect(
        () => JoinPayload.parseJoinUri(
          'soundmesh://join?room=$roomId&host=$hostAddress&port=$hostPort'
          '&version=1&token=$code&expires=not-a-number',
        ),
        throwsA(
          isA<JoinPayloadException>().having(
            (e) => e.code,
            'code',
            JoinPayloadErrorCode.invalidPayload,
          ),
        ),
      );
    });

    test('protocol version mismatch raises PROTOCOL_VERSION_UNSUPPORTED', () {
      expect(
        () => JoinPayload.parseJoinUri(
          'soundmesh://join?room=$roomId&host=$hostAddress&port=$hostPort'
          '&version=999&token=$code',
        ),
        throwsA(
          isA<JoinPayloadException>().having(
            (e) => e.code,
            'code',
            JoinPayloadErrorCode.protocolVersionUnsupported,
          ),
        ),
      );
    });

    test('error taxonomy contains the documented bootstrap error codes', () {
      expect(JoinPayloadErrorCode.invalidPayload.wireValue,
          equals('INVALID_PAYLOAD'));
      expect(JoinPayloadErrorCode.codeExpired.wireValue,
          equals('CODE_EXPIRED'));
      expect(JoinPayloadErrorCode.protocolVersionUnsupported.wireValue,
          equals('PROTOCOL_VERSION_UNSUPPORTED'));
      expect(JoinPayloadErrorCode.codeNotFound.wireValue,
          equals('CODE_NOT_FOUND'));
      expect(JoinPayloadErrorCode.roomNotFound.wireValue,
          equals('ROOM_NOT_FOUND'));
    });
  });

  group('JoinPayload / RoomAnnouncement Conversion', () {
    test('announcement round-trips through JoinPayload', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final announcement = RoomAnnouncement(
        code: code,
        hostIp: hostAddress,
        hostPort: hostPort,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: roomId,
        hostName: 'Test Host',
        expiresAt: expiresAt,
      );

      final payload = JoinPayload.fromAnnouncement(announcement);
      final rebuilt = payload.toAnnouncement(hostName: 'Test Host');

      expect(rebuilt.code, equals(announcement.code));
      expect(rebuilt.hostIp, equals(announcement.hostIp));
      expect(rebuilt.hostPort, equals(announcement.hostPort));
      expect(rebuilt.protocolVersion, equals(announcement.protocolVersion));
      expect(rebuilt.roomId, equals(announcement.roomId));
      expect(rebuilt.hostName, equals(announcement.hostName));
      expect(rebuilt.expiresAt, equals(expiresAt));
    });

    test('announcement JSON includes expires_at when expiration is set', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final announcement = RoomAnnouncement(
        code: code,
        hostIp: hostAddress,
        hostPort: hostPort,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: roomId,
        expiresAt: expiresAt,
      );

      final jsonString = announcement.toJsonString();
      expect(
        jsonString,
        contains('"expires_at":${expiresAt.millisecondsSinceEpoch}'),
      );

      final decoded = RoomAnnouncement.fromJsonString(jsonString);
      expect(decoded, isNotNull);
      expect(decoded!.expiresAt, equals(expiresAt));
    });

    test('announcement JSON without expiration omits expires_at', () {
      const announcement = RoomAnnouncement(
        code: code,
        hostIp: hostAddress,
        hostPort: hostPort,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: roomId,
      );

      final jsonString = announcement.toJsonString();
      expect(jsonString, isNot(contains('expires_at')));

      final decoded = RoomAnnouncement.fromJsonString(jsonString);
      expect(decoded, isNotNull);
      expect(decoded!.expiresAt, isNull);
    });

    test('announcement JSON round-trips expiration', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final original = RoomAnnouncement(
        code: code,
        hostIp: hostAddress,
        hostPort: hostPort,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: roomId,
        expiresAt: expiresAt,
      );

      final decoded = RoomAnnouncement.fromJsonString(
        original.toJsonString(),
      );

      expect(decoded, isNotNull);
      expect(decoded!.expiresAt, equals(expiresAt));
    });

    test('announcement isExpiredAt respects clock-skew allowance', () {
      final expiresAt = issuedAt.add(kJoinCodeLifetime);
      final announcement = RoomAnnouncement(
        code: code,
        hostIp: hostAddress,
        hostPort: hostPort,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: roomId,
        expiresAt: expiresAt,
      );

      expect(announcement.isExpiredAt(issuedAt), isFalse);
      expect(
        announcement.isExpiredAt(expiresAt.add(const Duration(seconds: 61))),
        isTrue,
      );
    });

    test('announcement without expiration never reports expired', () {
      const announcement = RoomAnnouncement(
        code: code,
        hostIp: hostAddress,
        hostPort: hostPort,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: roomId,
      );

      expect(announcement.isExpiredAt(DateTime.now()), isFalse);
    });
  });

  group('JoinPayloadException', () {
    test('toString includes wire value and message', () {
      const exception = JoinPayloadException(
        JoinPayloadErrorCode.invalidPayload,
        'test failure',
      );

      expect(exception.toString(), contains('INVALID_PAYLOAD'));
      expect(exception.toString(), contains('test failure'));
    });
  });
}
