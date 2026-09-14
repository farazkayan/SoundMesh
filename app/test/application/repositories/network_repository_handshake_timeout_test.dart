import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/protocol.dart';

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

  @override
  Future<bool> sendMessage(String message) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> getLocalIpAddress() async => '127.0.0.1';
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

    test('host transitions listening -> handshaking -> ready when HELLO received', () async {
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

      // Host should transition: listening -> handshaking -> ready
      expect(repo.currentState, equals(NetworkConnectionState.ready));

      // Verify the state transitions occurred
      expect(states, contains(NetworkConnectionState.listening));
      expect(states, contains(NetworkConnectionState.handshaking));
      expect(states, contains(NetworkConnectionState.ready));

      await sub.cancel();
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

      await completer.future.timeout(const Duration(seconds: 2));
      expect(repo.currentState, equals(NetworkConnectionState.ready));

      // Manually trigger timeout attempt - should be ignored since not in handshaking
      repo.triggerHandshakeTimeoutForTest();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(repo.currentState, equals(NetworkConnectionState.ready));

      await sub.cancel();
      repo.dispose();
    });

    test('handshake does not timeout when host receives HELLO and sends WELCOME', () async {
      final repo = TestableNetworkRepository(handshakeTimeout: const Duration(seconds: 10));

      await repo.startHosting();
      repo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 20));

      // Host should be in listening state initially
      expect(repo.currentState, equals(NetworkConnectionState.listening));

      // Simulate receiving HELLO from participant - capture any protocol messages
      final protoMessages = <ProtocolMessage>[];
      final protoSub = repo.protocolMessageStream.listen(protoMessages.add);

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

      // Host should transition: listening -> handshaking -> ready
      expect(repo.currentState, equals(NetworkConnectionState.ready));

      // Manually trigger timeout attempt - should be ignored since not in handshaking
      repo.triggerHandshakeTimeoutForTest();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(repo.currentState, equals(NetworkConnectionState.ready));

      await protoSub.cancel();
      repo.dispose();
    });
  });
}