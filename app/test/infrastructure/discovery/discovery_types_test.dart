// Unit tests for discovery protocol: code generation, payload encoding/decoding.

import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_types.dart';

void main() {
  group('Room Code Generation', () {
    test('generateRoomCode produces 6-digit numeric string', () {
      final code = generateRoomCode();
      
      expect(code.length, equals(6));
      expect(code, matches(RegExp(r'^\d{6}$')));
      expect(int.tryParse(code), isNotNull);
    });

    test('generateRoomCode produces codes in valid range', () {
      for (int i = 0; i < 100; i++) {
        final code = generateRoomCode();
        final value = int.parse(code);
        expect(value, greaterThanOrEqualTo(100000));
        expect(value, lessThanOrEqualTo(999999));
      }
    });

    test('isValidRoomCode validates correct codes', () {
      expect(isValidRoomCode('123456'), isTrue);
      expect(isValidRoomCode('000000'), isTrue);
      expect(isValidRoomCode('999999'), isTrue);
    });

    test('isValidRoomCode rejects invalid codes', () {
      expect(isValidRoomCode('12345'), isFalse); // Too short
      expect(isValidRoomCode('1234567'), isFalse); // Too long
      expect(isValidRoomCode('abcdef'), isFalse); // Non-numeric
      expect(isValidRoomCode('12-456'), isFalse); // Contains dash
      expect(isValidRoomCode(''), isFalse); // Empty
      expect(isValidRoomCode(' 123456'), isFalse); // Whitespace
    });
  });

  group('RoomAnnouncement Encoding/Decoding', () {
    test('toJsonString produces valid JSON', () {
      const announcement = RoomAnnouncement(
        code: '123456',
        hostIp: '192.168.1.100',
        hostPort: 8080,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: 'room-test-001',
        hostName: 'Test Host',
      );

      final jsonString = announcement.toJsonString();
      expect(jsonString, contains('"type":"room_announcement"'));
      expect(jsonString, contains('"version":1'));
      expect(jsonString, contains('"code":"123456"'));
      expect(jsonString, contains('"host_ip":"192.168.1.100"'));
      expect(jsonString, contains('"host_port":8080'));
      expect(jsonString, contains('"room_id":"room-test-001"'));
      expect(jsonString, contains('"host_name":"Test Host"'));
    });

    test('toJsonString works without optional hostName', () {
      const announcement = RoomAnnouncement(
        code: '654321',
        hostIp: '10.0.0.1',
        hostPort: 54321,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: 'room-test-002',
        hostName: null,
      );

      final jsonString = announcement.toJsonString();
      expect(jsonString, isNot(contains('host_name')));
    });

    test('fromJsonString decodes valid announcement', () {
      const original = RoomAnnouncement(
        code: '123456',
        hostIp: '192.168.1.100',
        hostPort: 8080,
        protocolVersion: kDiscoveryProtocolVersion,
        roomId: 'room-test-001',
        hostName: 'Test Host',
      );

      final jsonString = original.toJsonString();
      final decoded = RoomAnnouncement.fromJsonString(jsonString);

      expect(decoded, isNotNull);
      expect(decoded!.code, equals('123456'));
      expect(decoded.hostIp, equals('192.168.1.100'));
      expect(decoded.hostPort, equals(8080));
      expect(decoded.protocolVersion, equals(kDiscoveryProtocolVersion));
      expect(decoded.roomId, equals('room-test-001'));
      expect(decoded.hostName, equals('Test Host'));
    });

    test('fromJsonString rejects wrong message type', () {
      final jsonString = '{"type":"room_query","version":1,"code":"123456","host_ip":"1.2.3.4","host_port":8080,"room_id":"test"}';
      final decoded = RoomAnnouncement.fromJsonString(jsonString);
      expect(decoded, isNull);
    });

    test('fromJsonString rejects wrong protocol version', () {
      final jsonString = '{"type":"room_announcement","version":999,"code":"123456","host_ip":"1.2.3.4","host_port":8080,"room_id":"test"}';
      final decoded = RoomAnnouncement.fromJsonString(jsonString);
      expect(decoded, isNull);
    });

    test('fromJsonString rejects invalid code format', () {
      final jsonString = '{"type":"room_announcement","version":1,"code":"ABCDEF","host_ip":"1.2.3.4","host_port":8080,"room_id":"test"}';
      final decoded = RoomAnnouncement.fromJsonString(jsonString);
      expect(decoded, isNull);
    });

    test('fromJsonString rejects missing required fields', () {
      final jsonString = '{"type":"room_announcement","version":1,"code":"123456"}';
      final decoded = RoomAnnouncement.fromJsonString(jsonString);
      expect(decoded, isNull);
    });

    test('fromJsonString handles malformed JSON gracefully', () {
      final decoded = RoomAnnouncement.fromJsonString('not valid json');
      expect(decoded, isNull);
    });
  });

  group('Discovery Constants', () {
    test('kDiscoveryPort has expected value', () {
      expect(kDiscoveryPort, equals(54321));
    });

    test('kDiscoveryBroadcastIntervalSeconds has expected value', () {
      expect(kDiscoveryBroadcastIntervalSeconds, equals(2));
    });

    test('kDiscoveryScanTimeoutSeconds has expected value', () {
      expect(kDiscoveryScanTimeoutSeconds, equals(15));
    });

    test('kDiscoveryMaxPayloadSize has expected value', () {
      expect(kDiscoveryMaxPayloadSize, equals(512));
    });

    test('kDiscoveryProtocolVersion has expected value', () {
      expect(kDiscoveryProtocolVersion, equals(1));
    });
  });
}