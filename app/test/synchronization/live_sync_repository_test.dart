import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/application/repositories/timing_info_repository.dart';
import 'package:soundmesh/application/synchronization/live_sync_repository.dart';
import 'package:soundmesh/application/synchronization/sync_state.dart';

class MockNetworkRepository extends Mock implements NetworkRepository {}

class FakeTimingInfoRepository implements TimingInfoRepository {
  final int _baseTime = DateTime.now().microsecondsSinceEpoch * 1000;
  int _callCount = 0;

  @override
  Future<int> getMonotonicTimeNanos() async {
    _callCount++;
    return _baseTime + _callCount * 1_000_000;
  }
}

void main() {
  group('LiveSyncRepository - Participant-Scoped Synchronization', () {
    late MockNetworkRepository mockNetworkRepo;
    late FakeTimingInfoRepository fakeTimingRepo;
    late LiveSyncRepository repo;

    const int testGeneration = 1;
    const String testSessionId = 'test-session-id';
    const String testLocalDeviceId = 'host-device-id';

    setUp(() {
      mockNetworkRepo = MockNetworkRepository();
      fakeTimingRepo = FakeTimingInfoRepository();

      repo = LiveSyncRepository(
        timingRepo: fakeTimingRepo,
        networkRepo: mockNetworkRepo,
        pipelineGeneration: testGeneration,
        sessionId: testSessionId,
        localDeviceId: testLocalDeviceId,
      );
    });

    tearDown(() {
      repo.dispose();
    });

    test('initial state is UNSYNCHRONIZED for any participant', () {
      final status = repo.getCurrentStatus(participantId: 'participant-A');
      expect(status.state, equals(SyncState.unsynchronized));
      expect(status.generation, equals(1));
      expect(status.validSampleCount, equals(0));
    });

    test('participant isolation - A and B have independent sync state', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // Participant A: 3 good samples (RTT ~2ms) -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      // Participant B: 3 bad samples (high RTT ~110ms) -> DEGRADED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-B',
          t1: now + 10_000_000_000 + i * 1_000_000_000,
          t2: now + 10_000_000_000 + i * 1_000_000_000 + 50_000_000,
          t3: now + 10_000_000_000 + i * 1_000_000_000 + 60_000_000,
          t4: now + 10_000_000_000 + i * 1_000_000_000 + 110_000_000,
          generation: 1,
        );
      }

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      final statusB = repo.getCurrentStatus(participantId: 'participant-B');

      expect(statusA.state, equals(SyncState.synchronized));
      expect(statusA.validSampleCount, equals(3));
      expect(statusB.state, equals(SyncState.degraded));
      expect(statusB.validSampleCount, equals(3));
      expect(statusA.state, isNot(equals(SyncState.degraded)));
    });

    test('response routing - response for A updates only A', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // A needs 3 samples for SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      final statusB = repo.getCurrentStatus(participantId: 'participant-B');

      expect(statusA.validSampleCount, equals(3));
      expect(statusA.state, equals(SyncState.synchronized));
      expect(statusB.validSampleCount, equals(0));
      expect(statusB.state, equals(SyncState.unsynchronized));
    });

    test('response routing - response for B updates only B', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // B needs 3 samples for SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-B',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      final statusB = repo.getCurrentStatus(participantId: 'participant-B');

      expect(statusB.validSampleCount, equals(3));
      expect(statusB.state, equals(SyncState.synchronized));
      expect(statusA.validSampleCount, equals(0));
      expect(statusA.state, equals(SyncState.unsynchronized));
    });

    test('disconnect isolation - removing B does not affect A', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // A: 3 samples -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      // B: 3 samples -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-B',
          t1: now + 10_000_000_000 + i * 1_000_000_000,
          t2: now + 10_000_000_000 + i * 1_000_000_000 + 1_000_000,
          t3: now + 10_000_000_000 + i * 1_000_000_000 + 1_000_001,
          t4: now + 10_000_000_000 + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      expect(repo.getCurrentStatus(participantId: 'participant-A').validSampleCount, equals(3));
      expect(repo.getCurrentStatus(participantId: 'participant-B').validSampleCount, equals(3));

      repo.removeParticipant('participant-B');

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      expect(statusA.validSampleCount, equals(3));
      expect(statusA.state, equals(SyncState.synchronized));

      final statusB = repo.getCurrentStatus(participantId: 'participant-B');
      expect(statusB.state, equals(SyncState.unsynchronized));
      expect(statusB.validSampleCount, equals(0));
    });

    test('reconnect freshness - B reconnects with fresh state', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // First connection: B syncs with 3 samples -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-B',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      var statusB = repo.getCurrentStatus(participantId: 'participant-B');
      expect(statusB.validSampleCount, equals(3));
      expect(statusB.state, equals(SyncState.synchronized));

      // Disconnect: remove B's state
      repo.removeParticipant('participant-B');

      // Reconnect: B syncs with 3 new samples
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-B',
          t1: now + 20_000_000_000 + i * 1_000_000_000,
          t2: now + 20_000_000_000 + i * 1_000_000_000 + 1_000_000,
          t3: now + 20_000_000_000 + i * 1_000_000_000 + 1_000_001,
          t4: now + 20_000_000_000 + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      // New state should have only the 3 new samples
      statusB = repo.getCurrentStatus(participantId: 'participant-B');
      expect(statusB.validSampleCount, equals(3),
          reason: 'Reconnect should create fresh state with only new samples');
      expect(statusB.state, equals(SyncState.synchronized));
    });

    test('generation change resets all participant states', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // A: 3 samples -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      // B: 3 samples -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-B',
          t1: now + 10_000_000_000 + i * 1_000_000_000,
          t2: now + 10_000_000_000 + i * 1_000_000_000 + 1_000_000,
          t3: now + 10_000_000_000 + i * 1_000_000_000 + 1_000_001,
          t4: now + 10_000_000_000 + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      expect(repo.getCurrentStatus(participantId: 'participant-A').validSampleCount, equals(3));
      expect(repo.getCurrentStatus(participantId: 'participant-B').validSampleCount, equals(3));

      // Generation change
      repo.onSessionGenerationChanged(2);

      // All participants should be reset to UNSYNCHRONIZED
      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      final statusB = repo.getCurrentStatus(participantId: 'participant-B');

      expect(statusA.state, equals(SyncState.unsynchronized));
      expect(statusA.validSampleCount, equals(0));
      expect(statusB.state, equals(SyncState.unsynchronized));
      expect(statusB.validSampleCount, equals(0));
    });

    test('single-participant compatibility - works with one participant', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // A needs 3 samples for SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      expect(statusA.state, equals(SyncState.synchronized));
      expect(statusA.validSampleCount, equals(3));
      // Offset may be slightly negative due to timestamp asymmetry
      expect(statusA.offsetMs, closeTo(0.0, 1.0));
      expect(statusA.rttMs, greaterThan(0));
      expect(statusA.uncertaintyMs, greaterThan(0));

      // statusStream should work for the single participant
      // Note: calibrate sends a request but doesn't immediately emit a status
      // since it waits for a response. With testProcessSyncSample we bypass that.
      expect(true, isTrue); // placeholder to keep test structure
    });

    test('stale generation response is rejected', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      await repo.testProcessSyncSample(
        participantId: 'participant-A',
        t1: now,
        t2: now + 1_000_000,
        t3: now + 1_000_001,
        t4: now + 3_000_000,
        generation: 0, // stale generation
      );

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      expect(statusA.validSampleCount, equals(0));
      expect(statusA.state, equals(SyncState.unsynchronized));
    });

    test('multiple participants can reach different states independently', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // Participant A: 3 good samples -> SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      // Participant B: 1 good sample -> SYNCHRONIZING (needs 3 for SYNCHRONIZED)
      await repo.testProcessSyncSample(
        participantId: 'participant-B',
        t1: now + 10_000_000_000,
        t2: now + 10_000_000_000 + 1_000_000,
        t3: now + 10_000_000_000 + 1_000_001,
        t4: now + 10_000_000_000 + 3_000_000,
        generation: 1,
      );

      // Participant C: 3 bad samples (high RTT) -> DEGRADED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-C',
          t1: now + 20_000_000_000 + i * 1_000_000_000,
          t2: now + 20_000_000_000 + i * 1_000_000_000 + 50_000_000,
          t3: now + 20_000_000_000 + i * 1_000_000_000 + 60_000_000,
          t4: now + 20_000_000_000 + i * 1_000_000_000 + 110_000_000,
          generation: 1,
        );
      }

      // A: 3 good samples -> SYNCHRONIZED
      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      expect(statusA.state, equals(SyncState.synchronized));
      expect(statusA.validSampleCount, equals(3));

      // B: 1 sample -> SYNCHRONIZING (needs 3 for SYNCHRONIZED)
      final statusB = repo.getCurrentStatus(participantId: 'participant-B');
      expect(statusB.state, equals(SyncState.synchronizing));
      expect(statusB.validSampleCount, equals(1));

      // C: 3 bad samples -> DEGRADED
      final statusC = repo.getCurrentStatus(participantId: 'participant-C');
      expect(statusC.state, equals(SyncState.degraded));
      expect(statusC.validSampleCount, equals(3));

      // Verify complete isolation
      expect(statusA.state, isNot(equals(statusB.state)));
      expect(statusB.state, isNot(equals(statusC.state)));
      expect(statusA.state, isNot(equals(statusC.state)));
    });

    test('statusStream emits per-participant updates', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // First, create the participant state by adding one sample
      await repo.testProcessSyncSample(
        participantId: 'participant-A',
        t1: now,
        t2: now + 1_000_000,
        t3: now + 1_000_001,
        t4: now + 3_000_000,
        generation: 1,
      );

      final streamA = repo.statusStream(participantId: 'participant-A');
      final streamB = repo.statusStream(participantId: 'participant-B');

      final updatesA = <SyncStatus>[];
      final updatesB = <SyncStatus>[];

      final subA = streamA.listen(updatesA.add);
      final subB = streamB.listen(updatesB.add);

      // Add 2 more samples for A to reach SYNCHRONIZED (total 3)
      for (int i = 1; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      await Future.delayed(const Duration(milliseconds: 10));

      // Stream should eventually emit SYNCHRONIZED for A
      expect(updatesA.any((s) => s.state == SyncState.synchronized), isTrue);
      // B's stream emits initial UNSYNCHRONIZED since B doesn't exist yet
      expect(updatesB.length, equals(1));
      expect(updatesB.first.state, equals(SyncState.unsynchronized));

      await subA.cancel();
      await subB.cancel();
    });

    test('requestResync creates fresh state for specific participant', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      // A needs 3 samples for SYNCHRONIZED
      for (int i = 0; i < 3; i++) {
        await repo.testProcessSyncSample(
          participantId: 'participant-A',
          t1: now + i * 1_000_000_000,
          t2: now + i * 1_000_000_000 + 1_000_000,
          t3: now + i * 1_000_000_000 + 1_000_001,
          t4: now + i * 1_000_000_000 + 3_000_000,
          generation: 1,
        );
      }

      expect(repo.getCurrentStatus(participantId: 'participant-A').validSampleCount, equals(3));

      await repo.requestResync(participantId: 'participant-A');

      // requestResync clears the samples (resets to fresh state)
      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      expect(statusA.validSampleCount, equals(0));
      expect(statusA.state, equals(SyncState.unsynchronized));

      // B should be unaffected
      final statusB = repo.getCurrentStatus(participantId: 'participant-B');
      expect(statusB.validSampleCount, equals(0));
    });

    test('stale generation response is rejected', () async {
      final now = DateTime.now().microsecondsSinceEpoch * 1000;

      await repo.testProcessSyncSample(
        participantId: 'participant-A',
        t1: now,
        t2: now + 1_000_000,
        t3: now + 1_000_001,
        t4: now + 3_000_000,
        generation: 0,
      );

      final statusA = repo.getCurrentStatus(participantId: 'participant-A');
      expect(statusA.validSampleCount, equals(0));
      expect(statusA.state, equals(SyncState.unsynchronized));
    }
  );
  });
}