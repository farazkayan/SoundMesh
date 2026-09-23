import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/synchronization/offset_estimator.dart';

void main() {
  group('OffsetEstimator', () {
    test('zero offset with symmetric delay', () {
      final result = OffsetEstimator.compute(t1: 1000, t2: 1005, t3: 1006, t4: 1011);
      expect(result.offsetNs, equals(0));
      expect(result.rttNs, equals(10));
      expect(result.uncertaintyNs, equals(5));
    });

    test('positive offset (host ahead)', () {
      // Host ahead: forward=15, reverse=5, processing=0
      // t1=1000, t2=1015, t3=1015, t4=1020
      // RTT = 20, offset = (15-5)/2 = 5
      final result = OffsetEstimator.compute(t1: 1000, t2: 1015, t3: 1015, t4: 1020);
      expect(result.offsetNs, equals(5));
      expect(result.rttNs, equals(20));
      expect(result.uncertaintyNs, equals(10));
    });

    test('negative offset (host behind)', () {
      // Host behind: forward=5, reverse=15, processing=0
      // t1=1000, t2=1005, t3=1005, t4=1020
      // RTT = 20, offset = (5-15)/2 = -5
      final result = OffsetEstimator.compute(t1: 1000, t2: 1005, t3: 1005, t4: 1020);
      expect(result.offsetNs, equals(-5));
      expect(result.rttNs, equals(20));
      expect(result.uncertaintyNs, equals(10));
    });

    test('asymmetric delay produces bias', () {
      // Forward delay 20ms, reverse delay 10ms
      // t1=0, t2=20,000,000, t3=20,000,001, t4=30,000,001
      final result = OffsetEstimator.compute(
        t1: 0,
        t2: 20_000_000,
        t3: 20_000_001,
        t4: 30_000_001,
      );
      // RTT = (30,000,001 - 0) - (20,000,001 - 20,000,000) = 30,000,001 - 1 = 30,000,000
      // offset = ((20,000,000 - 0) + (20,000,001 - 30,000,001)) / 2 = (20,000,000 + -10,000,000) / 2 = 5,000,000
      expect(result.rttNs, equals(30_000_000));
      expect(result.offsetNs, equals(5_000_000));
      expect(result.uncertaintyNs, equals(15_000_000));
    });

    test('computeRtt formula', () {
      // (1011 - 1000) - (1006 - 1005) = 11 - 1 = 10
      expect(OffsetEstimator.computeRtt(t1: 1000, t2: 1005, t3: 1006, t4: 1011), equals(10));
      // (200 - 0) - (101 - 100) = 200 - 1 = 199
      expect(OffsetEstimator.computeRtt(t1: 0, t2: 100, t3: 101, t4: 200), equals(199));
    });

    test('computeOffset formula', () {
      // ((1005 - 1000) + (1006 - 1011)) / 2 = (5 + -5) / 2 = 0
      expect(OffsetEstimator.computeOffset(t1: 1000, t2: 1005, t3: 1006, t4: 1011), equals(0));
      // ((1015 - 1000) + (1015 - 1020)) / 2 = (15 + -5) / 2 = 5
      expect(OffsetEstimator.computeOffset(t1: 1000, t2: 1015, t3: 1015, t4: 1020), equals(5));
      // ((1005 - 1000) + (1005 - 1020)) / 2 = (5 + -15) / 2 = -5
      expect(OffsetEstimator.computeOffset(t1: 1000, t2: 1005, t3: 1005, t4: 1020), equals(-5));
    });

    test('computeUncertainty is RTT/2', () {
      expect(OffsetEstimator.computeUncertainty(rtt: 10), equals(5));
      expect(OffsetEstimator.computeUncertainty(rtt: 100), equals(50));
    });

    test('isValidOrdering rejects t4 < t1', () {
      expect(OffsetEstimator.isValidOrdering(t1: 1000, t2: 1005, t3: 1006, t4: 999), isFalse);
    });

    test('isValidOrdering rejects t3 < t2', () {
      expect(OffsetEstimator.isValidOrdering(t1: 1000, t2: 1005, t3: 1004, t4: 1011), isFalse);
    });

    test('isValidOrdering accepts valid timestamps', () {
      expect(OffsetEstimator.isValidOrdering(t1: 1000, t2: 1005, t3: 1006, t4: 1011), isTrue);
    });

    test('isValidRtt rejects zero or negative', () {
      expect(OffsetEstimator.isValidRtt(0), isFalse);
      expect(OffsetEstimator.isValidRtt(-1), isFalse);
      expect(OffsetEstimator.isValidRtt(1), isTrue);
    });
  });
}