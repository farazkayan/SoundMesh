import 'package:flutter_test/flutter_test.dart';

class ErrorSample {
  final int localTimeNs;
  final int errorNs;
  final int framePos;
  final int generation;
  final int receivedAtNs;

  ErrorSample({
    required this.localTimeNs,
    required this.errorNs,
    required this.framePos,
    required this.generation,
    required this.receivedAtNs,
  });
}

class DriftEstimate {
  final double driftMsPerSecond;
  final int sampleCount;
  final int timeSpanNs;

  DriftEstimate({
    required this.driftMsPerSecond,
    required this.sampleCount,
    required this.timeSpanNs,
  });
}

class DriftEstimator {
  static DriftEstimate? estimate({
    required List<ErrorSample> samples,
    required int minSamples,
    required int minTimeSpanNs,
    required int maxSampleAgeNs,
    required int currentGeneration,
    required int nowNs,
  }) {
    // Filter by generation
    final genSamples = samples.where((s) => s.generation == currentGeneration).toList();
    if (genSamples.isEmpty) return null;

    // Filter by max age
    final recentSamples = genSamples
        .where((s) => nowNs - s.receivedAtNs <= maxSampleAgeNs)
        .toList();
    if (recentSamples.length < minSamples) return null;

    // Check time span
    final first = recentSamples.first;
    final last = recentSamples.last;
    final timeSpan = last.localTimeNs - first.localTimeNs;
    if (timeSpan < minTimeSpanNs) return null;

    // Linear regression
    final n = recentSamples.length.toDouble();
    final sumX = recentSamples.map((s) => s.localTimeNs.toDouble()).reduce((a, b) => a + b);
    final sumY = recentSamples.map((s) => s.errorNs.toDouble()).reduce((a, b) => a + b);
    final sumXY = recentSamples.map((s) => s.localTimeNs.toDouble() * s.errorNs.toDouble()).reduce((a, b) => a + b);
    final sumX2 = recentSamples.map((s) => s.localTimeNs.toDouble() * s.localTimeNs.toDouble()).reduce((a, b) => a + b);

    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0.0) return null;

    final slope = (n * sumXY - sumX * sumY) / denom;
    final driftMsPerSecond = slope * 1000.0; // ns/ns -> ms/s (slope is ns/ns, multiply by 1000 to get ms/s)

    return DriftEstimate(
      driftMsPerSecond: driftMsPerSecond,
      sampleCount: recentSamples.length,
      timeSpanNs: timeSpan,
    );
  }
}

void main() {
  group('DriftEstimator', () {
    const minSamples = 10;
    const minTimeSpanNs = 30_000_000_000;
    const maxSampleAgeNs = 120_000_000_000;
    const generation = 1;
    const baseTime = 1_000_000_000_000;
    const intervalNs = 4_000_000_000; // 4s apart -> 36s span for 10 samples

    test('constant offset + zero drift returns ~0 drift', () {
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * intervalNs; // 4s apart
        return ErrorSample(
          localTimeNs: t,
          errorNs: 5_000_000, // constant 5ms offset
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      expect(result, isNotNull);
      expect(result!.driftMsPerSecond.abs(), lessThan(0.1)); // ~0 ms/s
    });

    test('constant offset + positive drift returns positive drift', () {
      final driftRate = 0.5; // ms/s
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * intervalNs;
        final error = 5_000_000 + (driftRate * i * intervalNs / 1000).round(); // drift accumulates
        return ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      expect(result, isNotNull);
      expect(result?.driftMsPerSecond, greaterThan(0.3));
      expect(result?.driftMsPerSecond, lessThan(0.7));
    });

    test('constant offset + negative drift returns negative drift', () {
      final driftRate = -0.5; // ms/s
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * intervalNs;
        final error = 5_000_000 + (driftRate * i * intervalNs / 1000).round();
        return ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      expect(result, isNotNull);
      expect(result?.driftMsPerSecond, lessThan(-0.3));
      expect(result?.driftMsPerSecond, greaterThan(-0.7));
    });

    test('noisy measurements still converge', () {
      final driftRate = 0.3; // ms/s
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * intervalNs;
        final noise = (i * 7 % 11 - 5) * 100_000; // pseudo-random noise ±0.5ms
        final error = 5_000_000 + (driftRate * i * intervalNs / 1000).round() + noise;
        return ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      expect(result, isNotNull);
      expect((result!.driftMsPerSecond - 0.3).abs(), lessThan(0.2));
    });

    test('insufficient samples returns null', () {
      final samples = List.generate(minSamples - 1, (i) {
        final t = baseTime + i * intervalNs;
        return ErrorSample(
          localTimeNs: t,
          errorNs: 5_000_000,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      expect(result, isNull);
    });

    test('insufficient time span returns null', () {
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * 100_000_000; // 0.1s apart = 1s total
        return ErrorSample(
          localTimeNs: t,
          errorNs: 5_000_000,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * 100_000_000,
      );
      expect(result, isNull);
    });

    test('outliers do not produce false drift', () {
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * intervalNs;
        int error = 5_000_000;
        if (i == 5) error += 10_000_000; // large outlier at index 5
        return ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      // Single outlier should not create significant drift
      expect(result, isNotNull);
      expect(result!.driftMsPerSecond.abs(), lessThan(2.0));
    });

    test('generation change invalidates old samples', () {
      final samples = List.generate(minSamples + 5, (i) {
        final t = baseTime + i * intervalNs;
        final gen = i < 5 ? 1 : 2; // first 5 samples are gen 1, rest gen 2
        return ErrorSample(
          localTimeNs: t,
          errorNs: 5_000_000,
          framePos: 44100 * i,
          generation: gen,
          receivedAtNs: t,
        );
      });
      // Estimate for generation 2 (only 5+ samples, but we need minSamples)
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: 2,
        nowNs: baseTime + (minSamples + 5) * intervalNs,
      );
      // gen 2 has only (minSamples+5 - 5) = minSamples samples, should work if time span ok
      expect(result, isNotNull);
    });

    test('stale samples are rejected by maxSampleAge', () {
      final samples = List.generate(minSamples * 2, (i) {
        final t = baseTime + i * 1_000_000_000;
        return ErrorSample(
          localTimeNs: t,
          errorNs: 5_000_000,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      // Now is far ahead, old samples should be filtered
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples * 2) * 1_000_000_000 + maxSampleAgeNs + 1_000_000_000,
      );
      // All samples are older than maxSampleAge, should return null
      expect(result, isNull);
    });

    test('additive constant frame-origin offset does not change slope', () {
      // Same drift, but with +10000 frame constant offset
      final driftRate = 0.4;
      final samples = List.generate(minSamples, (i) {
        final t = baseTime + i * intervalNs;
        final error = 5_000_000 + (driftRate * i * intervalNs / 1000).round() + 10_000; // constant offset
        return ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: generation,
          receivedAtNs: t,
        );
      });
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: generation,
        nowNs: baseTime + (minSamples + 1) * intervalNs,
      );
      expect(result, isNotNull);
      expect((result!.driftMsPerSecond - 0.4).abs(), lessThan(0.15));
    });

    test('old-generation samples cannot influence new generation', () {
      // Create samples with strong drift in gen 1, zero drift in gen 2
      final samples = <ErrorSample>[];
      // Gen 1: strong positive drift
      for (int i = 0; i < minSamples; i++) {
        final t = baseTime + i * intervalNs;
        final error = 5_000_000 + (2.0 * i * intervalNs / 1000).round();
        samples.add(ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: 1,
          receivedAtNs: t,
        ));
      }
      // Gen 2: zero drift, but more recent
      for (int i = 0; i < minSamples; i++) {
        final t = baseTime + (minSamples + 1 + i) * intervalNs;
        final error = 5_000_000;
        samples.add(ErrorSample(
          localTimeNs: t,
          errorNs: error,
          framePos: 44100 * i,
          generation: 2,
          receivedAtNs: t,
        ));
      }
      final result = DriftEstimator.estimate(
        samples: samples,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
        maxSampleAgeNs: maxSampleAgeNs,
        currentGeneration: 2,
        nowNs: baseTime + (2 * minSamples + 1) * intervalNs,
      );
      expect(result, isNotNull);
      // Should reflect gen 2 (zero drift), not gen 1 (2 ms/s)
      expect(result!.driftMsPerSecond.abs(), lessThan(0.2));
    });
  });
}