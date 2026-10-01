import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/protocol.dart';
import 'package:soundmesh/application/room/room_lifecycle.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/providers/create_room_flow_provider.dart';
import 'package:soundmesh/application/providers/join_room_flow_provider.dart';
import 'package:soundmesh/application/providers/discovery_provider.dart';
import 'package:soundmesh/infrastructure/discovery/discovery_manager.dart';
import 'package:soundmesh/infrastructure/discovery/mock_discovery_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TestableNetworkRepository extends NetworkRepository {
  TestableNetworkRepository({Duration handshakeTimeout = const Duration(milliseconds: 100)})
      : super.test(handshakeTimeout);

  @override
  Future<bool> startHosting({int port = 8765, String? roomId}) async {
    await super.startHosting(port: port, roomId: roomId);
    return true;
  }

  @override
  Future<bool> connectToHost(String ipAddress, {int port = 8765}) async {
    await super.connectToHost(ipAddress, port: port);
    return true;
  }

  @override
  Future<bool> sendProtocolMessage(ProtocolMessage message) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<String> getLocalIpAddress() async => '127.0.0.1';

  @override
  Future<void> setHeartbeatConfig({int intervalMs = 5000, int timeoutMs = 15000}) async {}

  @override
  Future<bool> reconnectToHost(String ipAddress, {int port = 8765}) async => false;
}

class MockDiscoveryManager extends DiscoveryManager {
  MockDiscoveryManager() : super(platform: MockDiscoveryPlatform());

  @override
  Future<void> stopAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Membership Lifecycle Tests', () {
    late MockDiscoveryManager mockDiscoveryManager;

    setUp(() {
      mockDiscoveryManager = MockDiscoveryManager();
    });

    tearDown(() {});

    test('Participant receives complete membership including host after join', () async {
      final hostNetworkRepo = TestableNetworkRepository();
      final participantNetworkRepo = TestableNetworkRepository();
      
      // Host creates room
      final hostContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => hostNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => mockDiscoveryManager),
      ]);
      
      final hostCreateFlow = hostContainer.read(createRoomFlowProvider.notifier);
      
      hostCreateFlow.setRoomName('Test Room');
      await hostCreateFlow.createRoom();
      
      // Simulate host TCP ready
      hostNetworkRepo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Host should be in listening state
      expect(hostNetworkRepo.currentState, equals(NetworkConnectionState.listening));
      expect(hostNetworkRepo.roomLifecycleState, equals(RoomLifecycleState.discoverable));
      
      // Participant joins
      final participantContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => participantNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => mockDiscoveryManager),
      ]);
      
      final participantJoinFlow = participantContainer.read(joinRoomFlowProvider.notifier);
      
      participantJoinFlow.setHostIpAddress('192.168.1.1');
      participantJoinFlow.setHostPort(8765);
      await participantJoinFlow.joinRoom();
      
      // Simulate participant TCP connected
      participantNetworkRepo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Simulate HELLO received by host
      final hostParticipantId = hostNetworkRepo.participantId;
      final participantParticipantId = participantNetworkRepo.participantId;
      
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "$participantParticipantId",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Host should be in handshaking
      expect(hostNetworkRepo.currentState, equals(NetworkConnectionState.handshaking));
      
      // Simulate JOIN_REQUEST received by host
      final sessionId = hostNetworkRepo.sessionId!;
      final generation = hostNetworkRepo.generation;
      
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440001",
          "messageType": "JOIN_REQUEST",
          "sessionId": "$sessionId",
          "senderId": "$participantParticipantId",
          "generation": $generation,
          "timestamp": 1234567891,
          "payload": {"participantId": "$participantParticipantId", "displayName": "Test Participant"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Host should be ready
      expect(hostNetworkRepo.currentState, equals(NetworkConnectionState.ready));
      expect(hostNetworkRepo.roomLifecycleState, equals(RoomLifecycleState.ready));
      
      // Verify host's authoritative membership has both host and participant
      expect(hostNetworkRepo.joinedParticipantIds, contains(participantParticipantId));
      expect(hostNetworkRepo.joinedParticipantIds.length, equals(1)); // Only participant (host not in this set)
      
      // Now simulate participant receiving JOIN_ACCEPTED with members
      final joinAcceptedJson = '''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440002",
          "messageType": "JOIN_ACCEPTED",
          "sessionId": "$sessionId",
          "senderId": "$hostParticipantId",
          "generation": $generation,
          "timestamp": 1234567892,
          "payload": {
            "roomId": "${hostNetworkRepo.roomId}",
            "hostParticipantId": "$hostParticipantId",
            "participantId": "$participantParticipantId",
            "members": [
              {"participantId": "$hostParticipantId", "role": "HOST", "displayName": "Test Host"},
              {"participantId": "$participantParticipantId", "role": "PARTICIPANT", "displayName": "Test Participant"}
            ]
          }
        }
      ''';
      
      participantNetworkRepo.handleRawMessageForTest(joinAcceptedJson);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Participant should be ready
      expect(participantNetworkRepo.currentState, equals(NetworkConnectionState.ready));
      expect(participantNetworkRepo.roomLifecycleState, equals(RoomLifecycleState.ready));
      
      // Verify participant's NetworkRepository has correct membership
      expect(participantNetworkRepo.joinedParticipantIds, contains(hostParticipantId));
      expect(participantNetworkRepo.joinedParticipantIds, contains(participantParticipantId));
      expect(participantNetworkRepo.joinedParticipantIds.length, equals(2));
      
      // Now simulate ROOM_STATE broadcast from host
      final roomStateJson = '''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440003",
          "messageType": "ROOM_STATE",
          "sessionId": "$sessionId",
          "senderId": "$hostParticipantId",
          "generation": $generation,
          "timestamp": 1234567893,
          "payload": {
            "roomId": "${hostNetworkRepo.roomId}",
            "members": [
              {"participantId": "$hostParticipantId", "role": "HOST", "displayName": "Test Host"},
              {"participantId": "$participantParticipantId", "role": "PARTICIPANT", "displayName": "Test Participant"}
            ]
          }
        }
      ''';
      
      participantNetworkRepo.handleRawMessageForTest(roomStateJson);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify participant's membership still correct after ROOM_STATE
      expect(participantNetworkRepo.joinedParticipantIds.length, equals(2));
      expect(participantNetworkRepo.joinedParticipantIds, contains(hostParticipantId));
      expect(participantNetworkRepo.joinedParticipantIds, contains(participantParticipantId));
      
      hostContainer.dispose();
      participantContainer.dispose();
      hostNetworkRepo.dispose();
      participantNetworkRepo.dispose();
    });

    test('Host removes participant from membership on leave', () async {
      final hostNetworkRepo = TestableNetworkRepository();
      final participantNetworkRepo = TestableNetworkRepository();
      
      // Setup host and participant
      final hostContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => hostNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => mockDiscoveryManager),
      ]);
      
      final hostCreateFlow = hostContainer.read(createRoomFlowProvider.notifier);
      
      hostCreateFlow.setRoomName('Test Room');
      await hostCreateFlow.createRoom();
      hostNetworkRepo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      
      final participantContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => participantNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => mockDiscoveryManager),
      ]);
      
      final participantJoinFlow = participantContainer.read(joinRoomFlowProvider.notifier);
      participantJoinFlow.setHostIpAddress('192.168.1.1');
      participantJoinFlow.setHostPort(8765);
      await participantJoinFlow.joinRoom();
      participantNetworkRepo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      
      final hostParticipantId = hostNetworkRepo.participantId;
      final participantParticipantId = participantNetworkRepo.participantId;
      
      // Complete handshake: send HELLO first, then wait for sessionId to be generated
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "$participantParticipantId",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Now sessionId should be available after HELLO processing
      final sessionId = hostNetworkRepo.sessionId!;
      final generation = hostNetworkRepo.generation;
      
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440001",
          "messageType": "JOIN_REQUEST",
          "sessionId": "$sessionId",
          "senderId": "$participantParticipantId",
          "generation": $generation,
          "timestamp": 1234567891,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify participant is in host's membership
      expect(hostNetworkRepo.joinedParticipantIds, contains(participantParticipantId));
      
      // Simulate INTERNAL_PARTICIPANT_LEFT (from native when participant disconnects)
      final internalLeftJson = '''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440004",
          "messageType": "INTERNAL_PARTICIPANT_LEFT",
          "senderId": "$hostParticipantId",
          "sessionId": "$sessionId",
          "generation": 0,
          "timestamp": 1234567894,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''';
      
      hostNetworkRepo.handleRawMessageForTest(internalLeftJson);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Host should have removed participant from authoritative membership
      expect(hostNetworkRepo.joinedParticipantIds, isNot(contains(participantParticipantId)));
      expect(hostNetworkRepo.joinedParticipantIds.length, equals(0));
      
      hostContainer.dispose();
      participantContainer.dispose();
      hostNetworkRepo.dispose();
      participantNetworkRepo.dispose();
    });

test('Rejoin does not create duplicate membership entry', () async {
      final hostNetworkRepo = TestableNetworkRepository();
      final participantNetworkRepo = TestableNetworkRepository();
      
      final hostContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => hostNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => mockDiscoveryManager),
      ]);
      
      final hostCreateFlow = hostContainer.read(createRoomFlowProvider.notifier);
      hostCreateFlow.setRoomName('Test Room');
      await hostCreateFlow.createRoom();
      hostNetworkRepo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      
      final participantContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => participantNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => mockDiscoveryManager),
      ]);
      
      final participantJoinFlow = participantContainer.read(joinRoomFlowProvider.notifier);
      participantJoinFlow.setHostIpAddress('192.168.1.1');
      participantJoinFlow.setHostPort(8765);
      await participantJoinFlow.joinRoom();
      participantNetworkRepo.triggerTcpConnectedForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      
      final hostParticipantId = hostNetworkRepo.participantId;
      final participantParticipantId = participantNetworkRepo.participantId;
      
      // First join - send HELLO first
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440000",
          "messageType": "HELLO",
          "senderId": "$participantParticipantId",
          "generation": 0,
          "timestamp": 1234567890,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      final sessionId = hostNetworkRepo.sessionId!;
      final generation = hostNetworkRepo.generation;
      
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440001",
          "messageType": "JOIN_REQUEST",
          "sessionId": "$sessionId",
          "senderId": "$participantParticipantId",
          "generation": $generation,
          "timestamp": 1234567891,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(hostNetworkRepo.joinedParticipantIds, contains(participantParticipantId));
      
      // Participant leaves - simulate INTERNAL_PARTICIPANT_LEFT
      final internalLeftJson = '''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440004",
          "messageType": "INTERNAL_PARTICIPANT_LEFT",
          "senderId": "$hostParticipantId",
          "sessionId": "$sessionId",
          "generation": 0,
          "timestamp": 1234567894,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''';
      
      hostNetworkRepo.handleRawMessageForTest(internalLeftJson);
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(hostNetworkRepo.joinedParticipantIds, isNot(contains(participantParticipantId)));
      
      // Participant rejoins - new HELLO with same participantId
      // Host generates new sessionId for new connection
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440005",
          "messageType": "HELLO",
          "senderId": "$participantParticipantId",
          "generation": 0,
          "timestamp": 1234567895,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Host should be in handshaking again (waiting for JOIN_REQUEST)
      // Note: State may transition quickly if JOIN_REQUEST arrives, so we check membership directly
      // rather than relying on exact intermediate state timing.
      
      // New JOIN_REQUEST - use the new sessionId generated after rejoin HELLO
      final newSessionId = hostNetworkRepo.sessionId!;
      final newGeneration = hostNetworkRepo.generation;
      hostNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440006",
          "messageType": "JOIN_REQUEST",
          "sessionId": "$newSessionId",
          "senderId": "$participantParticipantId",
          "generation": $newGeneration,
          "timestamp": 1234567896,
          "payload": {"participantId": "$participantParticipantId"}
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Host should have participant in membership (not duplicated)
      expect(hostNetworkRepo.joinedParticipantIds, contains(participantParticipantId));
      expect(hostNetworkRepo.joinedParticipantIds.length, equals(1));
      
      hostContainer.dispose();
      participantContainer.dispose();
      hostNetworkRepo.dispose();
      participantNetworkRepo.dispose();
    });

    test('RoomLifecycleNotifier membership matches NetworkRepository after ROOM_STATE', () async {
      final testNetworkRepo = TestableNetworkRepository();
      final testDiscoveryManager = MockDiscoveryManager();
      
      final testContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => testNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => testDiscoveryManager),
      ]);
      
      testContainer.read(roomLifecycleProvider.notifier);
      
      // Simulate ROOM_STATE with host and participant (using valid UUIDs)
      final hostId = '550e8400-e29b-41d4-a716-446655440000';
      final participantId = '550e8400-e29b-41d4-a716-446655440001';
      final sessionId = '550e8400-e29b-41d4-a716-446655440002';
      
      final roomStateJson = '''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440007",
          "messageType": "ROOM_STATE",
          "sessionId": "$sessionId",
          "senderId": "$hostId",
          "generation": 0,
          "timestamp": 1234567897,
          "payload": {
            "roomId": "room-abc",
            "members": [
              {"participantId": "$hostId", "role": "HOST", "displayName": "Host Name"},
              {"participantId": "$participantId", "role": "PARTICIPANT", "displayName": "Participant Name"}
            ]
          }
        }
      ''';
      
      testNetworkRepo.handleRawMessageForTest(roomStateJson);
      await Future.delayed(const Duration(milliseconds: 50));
      
      // RoomLifecycleNotifier should have received ROOM_STATE and updated members
      final state = testContainer.read(roomLifecycleProvider);
      expect(state.members.length, equals(2));
      
      final hostMember = state.members.firstWhere((m) => m.role == RoomRole.host);
      final participantMember = state.members.firstWhere((m) => m.role == RoomRole.participant);
      
      expect(hostMember.participantId, equals(hostId));
      expect(hostMember.displayName, equals('Host Name'));
      expect(participantMember.participantId, equals(participantId));
      expect(participantMember.displayName, equals('Participant Name'));
      
      testContainer.dispose();
      testNetworkRepo.dispose();
    });

    test('Participant RoomLifecycleNotifier initializes membership from NetworkRepository on creation', () async {
      // This test verifies the fix for Bug 1: lazy initialization misses initial ROOM_STATE
      final testNetworkRepo = TestableNetworkRepository();
      final testDiscoveryManager = MockDiscoveryManager();
      
      // Pre-populate NetworkRepository with membership (simulating join already happened)
      final hostId = '550e8400-e29b-41d4-a716-446655440000';
      final participantId = '550e8400-e29b-41d4-a716-446655440001';
      final sessionId = '550e8400-e29b-41d4-a716-446655440002';
      
      // Manually set up NetworkRepository state as if join completed
      testNetworkRepo.handleRawMessageForTest('''
        {
          "protocolVersion": 1,
          "messageId": "550e8400-e29b-41d4-a716-446655440008",
          "messageType": "JOIN_ACCEPTED",
          "sessionId": "$sessionId",
          "senderId": "$hostId",
          "generation": 0,
          "timestamp": 1234567898,
          "payload": {
            "roomId": "room-abc",
            "hostParticipantId": "$hostId",
            "participantId": "$participantId",
            "members": [
              {"participantId": "$hostId", "role": "HOST", "displayName": "Host Name"},
              {"participantId": "$participantId", "role": "PARTICIPANT", "displayName": "Participant Name"}
            ]
          }
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify NetworkRepository has correct membership
      expect(testNetworkRepo.joinedParticipantIds.length, equals(2));
      expect(testNetworkRepo.joinedParticipantIds, contains(hostId));
      expect(testNetworkRepo.joinedParticipantIds, contains(participantId));
      
      // NOW create RoomLifecycleNotifier (simulating lazy initialization when UI first watches)
      final testContainer = ProviderContainer(overrides: [
        networkRepositoryProvider.overrideWith((ref) => testNetworkRepo),
        discoveryManagerProvider.overrideWith((ref) => testDiscoveryManager),
      ]);
      
      testContainer.read(roomLifecycleProvider.notifier);
      
      // RoomLifecycleNotifier should sync membership from NetworkRepository on creation
      final state = testContainer.read(roomLifecycleProvider);
      
      // With the fix, members should be populated from NetworkRepository
      // Without the fix, members would be empty (initial state)
      expect(state.members.length, equals(2), reason: 'RoomLifecycleNotifier should initialize membership from NetworkRepository');
      
      testContainer.dispose();
      testNetworkRepo.dispose();
    });
  });
}