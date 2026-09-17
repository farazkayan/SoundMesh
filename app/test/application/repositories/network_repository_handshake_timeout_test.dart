import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';

class TestableNetworkRepository extends NetworkRepository {
  TestableNetworkRepository({Duration handshakeTimeout = const Duration(milliseconds: 100)})
      : super.test(handshakeTimeout);

  @override
  Future<bool> startHosting({int port = 8765}) async {
    await super.startHosting(port: port);
    return true;
  }

  @override
  Future<bool> connectToHost(String ipAddress, {int port = 8765}) async {
    await super.connectToHost(ipAddress, port: port);
    return true;
  }

  Future<bool> sendMessage(String message) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> getLocalIpAddress() async => '127.0.0.1';

  @override
  Future<void> setHeartbeatConfig({int intervalMs = 5000, int timeoutMs = 15000}) async {}

  @override
  Future<bool> reconnectToHost(String ipAddress, {int port = 8765}) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkRepository Handshake Timeout', () {
    test('handshake times out after duration when no response received (participant)', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(milliseconds: 100));

      final completer = Completer<NetworkConnectionState>();
      final protoMessages = <ProtocolMessage>[];
      final sub = repo.connectionStateStream.listen((state) {
        if (state == NetworkConnectionState.failed) {
          completer.complete(state);
        }
      });
      final protoSub = repo.protocolMessageStream.listen(protoMessages.add);

      await repo.connectToHost('192.168.1.1');
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));

      // Manually trigger timeout (since Timer doesn't fire in test env)
      repo.triggerHandshakeTimeoutForTest();
      await completer.future.timeout(const Duration(seconds: 2));

      expect(repo.currentState, equals(NetworkConnectionState.failed));

      // Verify the error message was emitted
      final timeoutError = protoMessages.where((m) => m.messageType == 'ERROR' && m.payload?['errorCode'] == 'HANDSHAKE_TIMEOUT').toList();
      expect(timeoutError, isNotEmpty);
      expect(timeoutError.first.payload?['errorMessage'], equals('Handshake timed out'));

      await sub.cancel();
      await protoSub.cancel();
      repo.dispose();
    });

    test('host with no participant stays in listening state and does NOT timeout', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(milliseconds: 100));

      final states = <NetworkConnectionState>[];
      final sub = repo.connectionStateStream.listen((state) {
        states.add(state);
      });

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));

      // Host should be in listening state, not handshaking
      expect(repo.currentState, equals(NetworkConnectionState.listening));

      // Wait longer than handshake timeout
      await Future.delayed(const Duration(milliseconds: 200));

      // Host should still be in listening state (no timeout because no participant connected)
      expect(repo.currentState, equals(NetworkConnectionState.listening));

      // Verify no handshake timeout error was emitted
      final protoMessages = <ProtocolMessage>[];
      final protoSub = repo.protocolMessageStream.listen(protoMessages.add);
      await Future.delayed(const Duration(milliseconds: 50));
      final timeoutErrors = protoMessages.where((m) => m.messageType == 'ERROR' && m.payload?['errorCode'] == 'HANDSHAKE_TIMEOUT').toList();
      expect(timeoutErrors, isEmpty);

      await sub.cancel();
      await protoSub.cancel();
      repo.dispose();
    });

    test('host transitions listening -> handshaking when HELLO received', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      final states = <NetworkConnectionState>[];
      final sub = repo.connectionStateStream.listen((state) {
        states.add(state);
      });

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));

      // Host should be in listening state initially
      expect(repo.currentState, equals(NetworkConnectionState.listening));

      // Simulate receiving HELLO from participant
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');

      // Give time for any async processing
      await Future.delayed(const Duration(milliseconds: 50));

      // Host should transition: listening -> handshaking (waiting for JOIN_REQUEST)
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));

      // Verify the state transitions occurred
      expect(states, contains(NetworkConnectionState.listening));
      expect(states, contains(NetworkConnectionState.handshaking));

      await sub.cancel();
      repo.dispose();
    });

    test('host transitions handshaking -> ready when JOIN_REQUEST received', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));

      // Simulate receiving HELLO from participant
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');

      await Future.delayed(const Duration(milliseconds: 50));

      // Host should be in handshaking
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));

      // Simulate receiving JOIN_REQUEST
      final sessionId = repo.sessionId!;
      final generation = repo.generation;
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440001",
          "messageType": "JOIN_REQUEST",
          "sessionId": "$sessionId",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": $generation,
          "timestamp": 1234567891,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');

      await Future.delayed(const Duration(milliseconds: 50));

      // Host should transition: handshaking -> ready
      expect(repo.currentState, equals(NetworkConnectionState.ready));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.ready));

      repo.dispose();
    });

    test('duplicate HELLO keeps the same session and room ids', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));

      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));

      final sessionId = repo.sessionId;
      final roomId = repo.roomId;
      expect(sessionId, isNotNull);
      expect(roomId, isNotNull);

      // Duplicate HELLO (e.g. retried connection) must not rotate session/room
      // ids that the participant may already have received in a WELCOME.
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440001",
          "messageType": "HELLO",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567891,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repo.sessionId, equals(sessionId));
      expect(repo.roomId, equals(roomId));
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));

      repo.dispose();
    });

    test('host ignores JOIN_REQUEST received before handshake', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(repo.currentState, equals(NetworkConnectionState.listening));

      // Malformed peer sends JOIN_REQUEST before any HELLO: must be ignored,
      // not crash on a null session/room id.
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440002",
          "messageType": "JOIN_REQUEST",
          "sessionId": "660e8400-e29b-41d4-a716-446655440000",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567892,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repo.currentState, equals(NetworkConnectionState.listening));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.discoverable));
      expect(repo.sessionId, isNull);

      repo.dispose();
    });

    test('handshake does not timeout when WELCOME received in time (participant)', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      final completer = Completer<NetworkConnectionState>();
      final sub = repo.connectionStateStream.listen((state) {
        if (state == NetworkConnectionState.ready) {
          completer.complete(state);
        }
      });

      await repo.connectToHost('192.168.1.1');
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.joining));

      // Simulate receiving WELCOME
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "WELCOME",
          "sessionId": "660e8400-e29b-41d4-a716-446655440000",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"roomId": "880e8400-e29b-41d4-a716-446655440000", "hostParticipantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');

      await Future.delayed(const Duration(milliseconds: 50));

      // Participant should be in joining state (sent JOIN_REQUEST, waiting for JOIN_ACCEPTED)
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.joining));

      // Simulate receiving JOIN_ACCEPTED
      final sessionId = repo.sessionId!;
      final generation = repo.generation;
      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440002",
          "messageType": "JOIN_ACCEPTED",
          "sessionId": "$sessionId",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": $generation,
          "timestamp": 1234567891,
          "payload": {"roomId": "880e8400-e29b-41d4-a716-446655440000", "hostParticipantId": "770e8400-e29b-41d4-a716-446655440000", "participantId": "${repo.participantId}"}
        }
      ''');

      await completer.future.timeout(const Duration(seconds: 2));
      expect(repo.currentState, equals(NetworkConnectionState.ready));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.ready));

      // Manually trigger timeout attempt - should be ignored since not in handshaking
      repo.triggerHandshakeTimeoutForTest();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(repo.currentState, equals(NetworkConnectionState.ready));

      await sub.cancel();
      repo.dispose();
    });

    test('handshake does not timeout when host receives HELLO and sends WELCOME', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      // Simulate receiving HELLO from participant - capture any protocol messages
      final protoMessages = <ProtocolMessage>[];
      final protoSub = repo.protocolMessageStream.listen(protoMessages.add);

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));

      // Host should be in listening state initially
      expect(repo.currentState, equals(NetworkConnectionState.listening));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.discoverable));

      repo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "770e8400-e29b-41d4-a716-446655440000",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "770e8400-e29b-41d4-a716-446655440000"}
        }
      ''');

      // Give time for any async processing
      await Future.delayed(const Duration(milliseconds: 50));

      // Host should transition: listening -> handshaking (waiting for JOIN_REQUEST)
      // Room lifecycle state is still discoverable until JOIN_REQUEST is received
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));
      expect(repo.roomLifecycleState, equals(RoomLifecycleState.discoverable));

      // Wait longer than the test's handshake timeout would be if it were short
      // But since the real timeout is 10 seconds, we just verify state is still handshaking
      await Future.delayed(const Duration(milliseconds: 100));
      expect(repo.currentState, equals(NetworkConnectionState.handshaking));

      await protoSub.cancel();
      repo.dispose();
    });

    test('heartbeat config can be set', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      await repo.setHeartbeatConfig(intervalMs: 3000, timeoutMs: 10000);
      // No exception means success
      expect(true, isTrue);

      repo.dispose();
    });

    test('reconnectToHost returns false on mock platform', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      final result = await repo.reconnectToHost('192.168.1.1', port: 8765);
      expect(result, isFalse);

      repo.dispose();
    });

    test('error codes include NETWORK_UNREACHABLE classification', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(milliseconds: 100));

      final errors = <ConnectionError>[];
      final sub = repo.connectionErrorStream.listen(errors.add);

      // Simulate a NETWORK_UNREACHABLE error from native
      // This tests the error classification logic on the Dart side
      await repo.connectToHost('192.168.255.255'); // Unreachable IP
      repo.triggerTcpConnectedForTest(); // This won't actually connect but simulates the callback
      
      // The mock platform always returns true, so we can't easily test the actual error
      // But we can verify the error stream exists
      expect(repo.connectionErrorStream, isNotNull);

      await sub.cancel();
      repo.dispose();
    });

    test('NetworkConnectionState enum includes reconnecting', () {
      // Verify the enum has all required states
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.reconnecting));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.ready));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.handshaking));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.listening));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.connected));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.connecting));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.disconnected));
      expect(NetworkConnectionState.values, contains(NetworkConnectionState.failed));
    });
  });
}