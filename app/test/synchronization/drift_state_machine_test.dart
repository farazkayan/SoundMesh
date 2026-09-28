import 'package:flutter_test/flutter_test.dart';

enum DriftState { unknown, calibrating, synchronized, degraded, failed }

class DriftStateMachine {
  DriftState currentState = DriftState.unknown;
  int currentGeneration = 0;

  static const double _syncThresholdMsPerS = 1.0;
  static const double _degradedThresholdMsPerS = 5.0;

  DriftState evaluate({
    required int validSampleCount,
    required int timeSpanNs,
    required double? driftMsPerSecond,
    required double? confidence,
    required int minSamples,
    required int minTimeSpanNs,
  }) {
    final int actualMinSamples = minSamples;
    final int actualMinTimeSpanNs = minTimeSpanNs;

    if (validSampleCount < actualMinSamples) {
      currentState = DriftState.unknown;
      return currentState;
    }

    if (timeSpanNs < actualMinTimeSpanNs) {
      currentState = DriftState.calibrating;
      return currentState;
    }

    if (driftMsPerSecond == null) {
      currentState = DriftState.calibrating;
      return currentState;
    }

    final absDrift = driftMsPerSecond.abs();

    switch (currentState) {
      case DriftState.unknown:
      case DriftState.calibrating:
        if (absDrift <= _syncThresholdMsPerS) {
          currentState = DriftState.synchronized;
        } else {
          currentState = DriftState.degraded;
        }
        break;
      case DriftState.synchronized:
        if (absDrift > _degradedThresholdMsPerS) {
          currentState = DriftState.degraded;
        }
        break;
      case DriftState.degraded:
        if (absDrift <= _syncThresholdMsPerS) {
          currentState = DriftState.synchronized;
        }
        break;
      case DriftState.failed:
        break;
    }

    return currentState;
  }

  void reset({required int generation}) {
    currentState = DriftState.unknown;
    currentGeneration = generation;
  }
}

void main() {
  group('DriftStateMachine', () {
    const minSamples = 10;
    const minTimeSpanNs = 30_000_000_000;

    test('initial state is UNKNOWN', () {
      final sm = DriftStateMachine();
      expect(sm.currentState, equals(DriftState.unknown));
    });

    test('insufficient samples -> UNKNOWN', () {
      final sm = DriftStateMachine();
      final state = sm.evaluate(
        validSampleCount: minSamples - 1,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 0.5,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.unknown));
    });

    test('sufficient samples but insufficient time span -> CALIBRATING', () {
      final sm = DriftStateMachine();
      final state = sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs ~/ 2,
        driftMsPerSecond: 0.5,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.calibrating));
    });

    test('sufficient samples and time span, zero drift -> SYNCHRONIZED', () {
      final sm = DriftStateMachine();
      final state = sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 0.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.synchronized));
    });

    test('sufficient samples and time span, small drift -> SYNCHRONIZED', () {
      final sm = DriftStateMachine();
      final state = sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 0.5,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.synchronized));
    });

    test('sufficient samples and time span, large drift -> DEGRADED', () {
      final sm = DriftStateMachine();
      final state = sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 10.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.degraded));
    });

    test('SYNCHRONIZED -> DEGRADED when drift exceeds degraded threshold', () {
      final sm = DriftStateMachine();
      sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 0.5,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(sm.currentState, equals(DriftState.synchronized));

      final state = sm.evaluate(
        validSampleCount: minSamples + 5,
        timeSpanNs: minTimeSpanNs * 3,
        driftMsPerSecond: 10.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.degraded));
    });

    test('DEGRADED -> SYNCHRONIZED when drift returns to sync threshold', () {
      final sm = DriftStateMachine();
      sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 10.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(sm.currentState, equals(DriftState.degraded));

      final state = sm.evaluate(
        validSampleCount: minSamples + 10,
        timeSpanNs: minTimeSpanNs * 4,
        driftMsPerSecond: 0.3,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.synchronized));
    });

    test('null drift -> CALIBRATING even with enough samples', () {
      final sm = DriftStateMachine();
      final state = sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: null,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.calibrating));
    });

    test('reset with new generation resets state', () {
      final sm = DriftStateMachine();
      sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 0.5,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(sm.currentState, equals(DriftState.synchronized));

      sm.reset(generation: 2);
      expect(sm.currentState, equals(DriftState.unknown));
      expect(sm.currentGeneration, equals(2));
    });

    test('hysteresis: DEGRADED with intermediate drift stays DEGRADED', () {
      final sm = DriftStateMachine();
      sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 10.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(sm.currentState, equals(DriftState.degraded));

      // Drift is 3.0 (between sync and degraded thresholds) - should stay DEGRADED
      final state = sm.evaluate(
        validSampleCount: minSamples + 5,
        timeSpanNs: minTimeSpanNs * 3,
        driftMsPerSecond: 3.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.degraded));
    });

    test('hysteresis: SYNCHRONIZED with intermediate drift stays SYNCHRONIZED', () {
      final sm = DriftStateMachine();
      sm.evaluate(
        validSampleCount: minSamples,
        timeSpanNs: minTimeSpanNs * 2,
        driftMsPerSecond: 0.5,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(sm.currentState, equals(DriftState.synchronized));

      // Drift is 3.0 (between sync and degraded thresholds) - should stay SYNCHRONIZED
      final state = sm.evaluate(
        validSampleCount: minSamples + 5,
        timeSpanNs: minTimeSpanNs * 3,
        driftMsPerSecond: 3.0,
        confidence: null,
        minSamples: minSamples,
        minTimeSpanNs: minTimeSpanNs,
      );
      expect(state, equals(DriftState.synchronized));
    });
  });
}