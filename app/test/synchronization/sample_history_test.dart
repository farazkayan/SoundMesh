import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/synchronization/sample_history.dart';

void main() {
  group('SampleHistory', () {
    int nowNs() => DateTime.now().microsecondsSinceEpoch * 1000;

    test('addSample adds to history', () {
      final history = SampleHistory(maxSamples: 5);
      final now = nowNs();
      final sample = SyncSample.fromExchange(
        t1: now, t2: now + 5, t3: now + 6, t4: now + 11,
        generation: 1,
        receivedAtNs: now + 11,
        valid: true,
      );
      history.addSample(sample);
      expect(history.getAllSamples().length, equals(1));
    });

    test('ring buffer evicts oldest when full', () {
      final history = SampleHistory(maxSamples: 3);
      final now = nowNs();
      for (int i = 0; i < 5; i++) {
        history.addSample(SyncSample.fromExchange(
          t1: now + i * 100, t2: now + i * 100 + 5, t3: now + i * 100 + 6, t4: now + i * 100 + 11,
          generation: 1,
          receivedAtNs: now + i * 100 + 11,
          valid: true,
        ));
      }
      expect(history.getAllSamples().length, equals(3));
      expect(history.getAllSamples().first.t1, equals(now + 200));
    });

    test('getValidSamples filters by generation', () {
      final history = SampleHistory();
      final now = nowNs();
      history.addSample(SyncSample.fromExchange(
        t1: now, t2: now + 5, t3: now + 6, t4: now + 11,
        generation: 1,
        receivedAtNs: now + 11,
        valid: true,
      ));
      history.addSample(SyncSample.fromExchange(
        t1: now + 1000, t2: now + 1005, t3: now + 1006, t4: now + 1011,
        generation: 2,
        receivedAtNs: now + 1011,
        valid: true,
      ));
      final valid = history.getValidSamples(currentGeneration: 1);
      expect(valid.length, equals(1));
      expect(valid.first.t1, equals(now));
    });

    test('getValidSamples excludes invalid samples', () {
      final history = SampleHistory();
      final now = nowNs();
      history.addSample(SyncSample.fromExchange(
        t1: now, t2: now + 5, t3: now + 6, t4: now + 11,
        generation: 1,
        receivedAtNs: now + 11,
        valid: true,
      ));
      history.addSample(SyncSample.fromExchange(
        t1: now + 1000, t2: now + 1005, t3: now + 1006, t4: now + 1011,
        generation: 1,
        receivedAtNs: now + 1011,
        valid: false,
        rejectionReason: 'test',
      ));
      final valid = history.getValidSamples(currentGeneration: 1);
      expect(valid.length, equals(1));
    });

// test('getBestSample returns minimum uncertainty', () {
//   final history = SampleHistory();
//   final base = nowNs() - 2_000_000_000; // 2 seconds ago to ensure both samples are in the past
//   history.addSample(SyncSample.fromExchange(
//     t1: base, t2: base + 20_000_000, t3: base + 20_000_001, t4: base + 30_000_001, // RTT=30ms, uncertainty=15ms
//     generation: 1,
//     receivedAtNs: base + 30_000_001,
//     valid: true,
//   ));
//   history.addSample(SyncSample.fromExchange(
//     t1: base + 1_000_000_000, t2: base + 1_000_005_000_000, t3: base + 1_000_006_000_000, t4: base + 1_000_011_000_000, // RTT=10ms, uncertainty=5ms
//     generation: 1,
//     receivedAtNs: base + 1_000_011_000_000,
//     valid: true,
//   ));
//   final best = history.getBestSample(currentGeneration: 1);
//   expect(best, isNotNull);
//   expect(best!.uncertaintyNs, equals(5_000_000));
// });

    test('getCurrentEstimate returns estimate from best sample', () {
      final history = SampleHistory();
      final now = nowNs();
      history.addSample(SyncSample.fromExchange(
        t1: now, t2: now + 5, t3: now + 6, t4: now + 11,
        generation: 1,
        receivedAtNs: now + 11,
        valid: true,
      ));
      final estimate = history.getCurrentEstimate(currentGeneration: 1);
      expect(estimate, isNotNull);
      expect(estimate!.offsetNs, equals(0));
      expect(estimate.rttNs, equals(10));
      expect(estimate.uncertaintyNs, equals(5));
    });

    test('getCurrentEstimate returns null for no valid samples', () {
      final history = SampleHistory();
      final estimate = history.getCurrentEstimate(currentGeneration: 1);
      expect(estimate, isNull);
    });

    test('getValidSampleCount counts correctly', () {
      final history = SampleHistory();
      final now = nowNs();
      history.addSample(SyncSample.fromExchange(
        t1: now, t2: now + 5, t3: now + 6, t4: now + 11,
        generation: 1,
        receivedAtNs: now + 11,
        valid: true,
      ));
      history.addSample(SyncSample.fromExchange(
        t1: now + 1000, t2: now + 1005, t3: now + 1006, t4: now + 1011,
        generation: 1,
        receivedAtNs: now + 1011,
        valid: false,
      ));
      expect(history.getValidSampleCount(currentGeneration: 1), equals(1));
    });

    test('clear removes all samples', () {
      final history = SampleHistory();
      final now = nowNs();
      history.addSample(SyncSample.fromExchange(
        t1: now, t2: now + 5, t3: now + 6, t4: now + 11,
        generation: 1,
        receivedAtNs: now + 11,
        valid: true,
      ));
      history.clear();
      expect(history.getAllSamples().isEmpty, isTrue);
    });
  });
}