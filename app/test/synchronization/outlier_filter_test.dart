import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/synchronization/outlier_filter.dart';
import 'package:soundmesh/application/synchronization/sample_history.dart';

void main() {
  group('OutlierFilter', () {
    test('validates correct ordering', () {
      final result = OutlierFilter.validate(
        t1: 1000, t2: 1005, t3: 1006, t4: 1011,
        generation: 1,
        currentGeneration: 1,
      );
      expect(result.valid, isTrue);
      expect(result.rejectionReason, isNull);
    });

    test('rejects t4 < t1', () {
      final result = OutlierFilter.validate(
        t1: 1000, t2: 1005, t3: 1006, t4: 999,
        generation: 1,
        currentGeneration: 1,
      );
      expect(result.valid, isFalse);
      expect(result.rejectionReason, equals('receive before send (t4 < t1)'));
    });

    test('rejects t3 < t2', () {
      final result = OutlierFilter.validate(
        t1: 1000, t2: 1005, t3: 1004, t4: 1011,
        generation: 1,
        currentGeneration: 1,
      );
      expect(result.valid, isFalse);
      expect(result.rejectionReason, equals('host send before receive (t3 < t2)'));
    });

    test('rejects invalid RTT (<= 0)', () {
      final result = OutlierFilter.validate(
        t1: 1000, t2: 1000, t3: 1000, t4: 1000,
        generation: 1,
        currentGeneration: 1,
      );
      expect(result.valid, isFalse);
      expect(result.rejectionReason, equals('invalid RTT (RTT <= 0)'));
    });

    test('rejects stale generation', () {
      final result = OutlierFilter.validate(
        t1: 1000, t2: 1005, t3: 1006, t4: 1011,
        generation: 1,
        currentGeneration: 2,
      );
      expect(result.valid, isFalse);
      expect(result.rejectionReason, equals('stale generation'));
    });

    int nowNs() => DateTime.now().microsecondsSinceEpoch * 1000;

    test('rejects RTT outlier after 5 samples', () {
      final now = nowNs();
      final samples = [
        SyncSample.fromExchange(t1: now, t2: now + 5, t3: now + 6, t4: now + 11, generation: 1, receivedAtNs: now + 11, valid: true),
        SyncSample.fromExchange(t1: now + 1000, t2: now + 1005, t3: now + 1006, t4: now + 1011, generation: 1, receivedAtNs: now + 1011, valid: true),
        SyncSample.fromExchange(t1: now + 2000, t2: now + 2005, t3: now + 2006, t4: now + 2011, generation: 1, receivedAtNs: now + 2011, valid: true),
        SyncSample.fromExchange(t1: now + 3000, t2: now + 3005, t3: now + 3006, t4: now + 3011, generation: 1, receivedAtNs: now + 3011, valid: true),
        SyncSample.fromExchange(t1: now + 4000, t2: now + 4005, t3: now + 4006, t4: now + 4011, generation: 1, receivedAtNs: now + 4011, valid: true),
      ];
      // Median RTT = 10, 3x = 30
      // This sample has RTT = 100 (> 30)
      final result = OutlierFilter.validate(
        t1: now + 5000, t2: now + 5005, t3: now + 5006, t4: now + 5100, // RTT = 94
        generation: 1,
        currentGeneration: 1,
        recentSamples: samples,
      );
      expect(result.valid, isFalse);
      expect(result.rejectionReason, equals('RTT outlier (rtt > 3 * medianRTT)'));
    });

    test('accepts RTT within 3x median', () {
      final now = nowNs();
      final samples = [
        SyncSample.fromExchange(t1: now, t2: now + 5, t3: now + 6, t4: now + 11, generation: 1, receivedAtNs: now + 11, valid: true),
        SyncSample.fromExchange(t1: now + 1000, t2: now + 1005, t3: now + 1006, t4: now + 1011, generation: 1, receivedAtNs: now + 1011, valid: true),
        SyncSample.fromExchange(t1: now + 2000, t2: now + 2005, t3: now + 2006, t4: now + 2011, generation: 1, receivedAtNs: now + 2011, valid: true),
        SyncSample.fromExchange(t1: now + 3000, t2: now + 3005, t3: now + 3006, t4: now + 3011, generation: 1, receivedAtNs: now + 3011, valid: true),
        SyncSample.fromExchange(t1: now + 4000, t2: now + 4005, t3: now + 4006, t4: now + 4011, generation: 1, receivedAtNs: now + 4011, valid: true),
      ];
      // Median RTT = 10, 3x = 30
      // This sample has RTT = 20 (< 30)
      final result = OutlierFilter.validate(
        t1: now + 5000, t2: now + 5005, t3: now + 5006, t4: now + 5025, // RTT = 20
        generation: 1,
        currentGeneration: 1,
        recentSamples: samples,
      );
      expect(result.valid, isTrue);
    });

    // test('rejects offset outlier after 5 samples', () {
//   final base = nowNs() - 10_000_000_000;
//   final samples = [
//     SyncSample.fromExchange(t1: base, t2: base + 5_000_000, t3: base + 5_000_001, t4: base + 10_000_001, generation: 1, receivedAtNs: base + 10_000_001, valid: true), // offset=0
//     SyncSample.fromExchange(t1: base + 1_000_000_000, t2: base + 1_000_005_000_000, t3: base + 1_000_005_000_001, t4: base + 1_000_010_000_001, generation: 1, receivedAtNs: base + 1_000_010_000_001, valid: true), // offset=0
//     SyncSample.fromExchange(t1: base + 2_000_000_000, t2: base + 2_000_005_000_000, t3: base + 2_000_005_000_001, t4: base + 2_000_010_000_001, generation: 1, receivedAtNs: base + 2_000_010_000_001, valid: true), // offset=0
//     SyncSample.fromExchange(t1: base + 3_000_000_000, t2: base + 3_000_005_000_000, t3: base + 3_000_005_000_001, t4: base + 3_000_010_000_001, generation: 1, receivedAtNs: base + 3_000_010_000_001, valid: true), // offset=0
//     SyncSample.fromExchange(t1: base + 4_000_000_000, t2: base + 4_000_005_000_000, t3: base + 4_000_005_000_001, t4: base + 4_000_010_000_001, generation: 1, receivedAtNs: base + 4_000_010_000_001, valid: true), // offset=0
//   ];
//   // Median offset = 0, MAD = 0 (all offsets are 0)
//   // With MAD = 0, the check should pass (no outlier detection)
//   // New sample: forward=15ms, reverse=5ms, RTT=20ms, offset=5ms
//   final result = OutlierFilter.validate(
//     t1: base + 5_000_000_000, t2: base + 5_000_015_000_000, t3: base + 5_000_015_000_001, t4: base + 5_000_020_000_001,
//     generation: 1,
//     currentGeneration: 1,
//     recentSamples: samples,
//   );
//   // When MAD is 0, the check should pass (no outlier detection)
//   expect(result.valid, isTrue);
// });

    test('does not apply median filter before 5 samples', () {
      final now = nowNs();
      final samples = [
        SyncSample.fromExchange(t1: now, t2: now + 5, t3: now + 6, t4: now + 11, generation: 1, receivedAtNs: now + 11, valid: true),
        SyncSample.fromExchange(t1: now + 1000, t2: now + 1005, t3: now + 1006, t4: now + 1011, generation: 1, receivedAtNs: now + 1011, valid: true),
        SyncSample.fromExchange(t1: now + 2000, t2: now + 2005, t3: now + 2006, t4: now + 2011, generation: 1, receivedAtNs: now + 2011, valid: true),
      ];
      // Only 3 samples, median filter should not apply
      final result = OutlierFilter.validate(
        t1: now + 3000, t2: now + 3005, t3: now + 3006, t4: now + 3100, // RTT = 94 (would be outlier if median applied)
        generation: 1,
        currentGeneration: 1,
        recentSamples: samples,
      );
      expect(result.valid, isTrue);
    });
  });

  group('_computeMedian', () {
    test('computes median for odd count', () {
      // Use reflection or test via public API
      // Since _computeMedian is private, we test through validate
      // This is just a placeholder for the test structure
    });

    test('computes median for even count', () {
      // Same as above
    });
  });
}