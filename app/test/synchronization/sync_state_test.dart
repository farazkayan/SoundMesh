import 'package:flutter_test/flutter_test.dart';
import 'package:soundmesh/application/synchronization/sync_state.dart';
import 'package:soundmesh/application/synchronization/offset_estimator.dart';

void main() {
  group('SyncStateMachine', () {
    test('initial state is UNSYNCHRONIZED', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      expect(sm.currentState, equals(SyncState.unsynchronized));
    });

    test('no samples -> UNSYNCHRONIZED', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      final state = sm.evaluate(
        validSampleCount: 0,
        currentUncertaintyNs: null,
        hasUsableEstimate: false,
      );
      expect(state, equals(SyncState.unsynchronized));
    });

    test('1-2 samples -> SYNCHRONIZING', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      var state = sm.evaluate(
        validSampleCount: 1,
        currentUncertaintyNs: 10_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.synchronizing));

      state = sm.evaluate(
        validSampleCount: 2,
        currentUncertaintyNs: 10_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.synchronizing));
    });

    test('3 samples with uncertainty <= 5ms -> SYNCHRONIZED', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      // First call: UNSYNCHRONIZED -> SYNCHRONIZING
      sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 5_000_000,
        hasUsableEstimate: true,
      );
      // Second call: SYNCHRONIZING -> SYNCHRONIZED
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 5_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.synchronized));
    });

    test('3 samples with uncertainty 5-20ms -> SYNCHRONIZING', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      // First call: UNSYNCHRONIZED -> SYNCHRONIZING
      sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 10_000_000,
        hasUsableEstimate: true,
      );
      // Second call: stays SYNCHRONIZING (uncertainty 5-20ms)
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 10_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.synchronizing));
    });

    test('uncertainty > 20ms -> DEGRADED', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      // First call: UNSYNCHRONIZED -> SYNCHRONIZING
      sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 25_000_000,
        hasUsableEstimate: true,
      );
      // Second call: SYNCHRONIZING -> DEGRADED
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 25_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.degraded));
    });

    test('SYNCHRONIZED -> DEGRADED when uncertainty > 20ms', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      // First call: UNSYNCHRONIZED -> SYNCHRONIZING
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      // Second call: SYNCHRONIZING -> SYNCHRONIZED
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.synchronized));

      // Third call: SYNCHRONIZED -> DEGRADED
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 25_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.degraded));
    });

    test('DEGRADED -> SYNCHRONIZED when uncertainty <= 5ms and >= 3 samples', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      // First call: UNSYNCHRONIZED -> SYNCHRONIZING
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 25_000_000, hasUsableEstimate: true);
      // Second call: SYNCHRONIZING -> DEGRADED
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 25_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.degraded));

      // Third call: DEGRADED -> SYNCHRONIZED
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 5_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.synchronized));
    });

    test('SYNCHRONIZED with uncertainty 10ms stays SYNCHRONIZED (hysteresis)', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.synchronized));

      // Uncertainty rises to 10ms (5-20ms range) - should stay SYNCHRONIZED
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 10_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.synchronized));
    });

    test('DEGRADED with uncertainty 10ms stays DEGRADED (hysteresis)', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 25_000_000, hasUsableEstimate: true);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 25_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.degraded));

      // Uncertainty improves to 10ms (5-20ms range) - should stay DEGRADED
      final state = sm.evaluate(
        validSampleCount: 3,
        currentUncertaintyNs: 10_000_000,
        hasUsableEstimate: true,
      );
      expect(state, equals(SyncState.degraded));
    });

    test('all samples stale -> UNSYNCHRONIZED', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.synchronized));

      final state = sm.evaluate(
        validSampleCount: 0,
        currentUncertaintyNs: null,
        hasUsableEstimate: false,
      );
      expect(state, equals(SyncState.unsynchronized));
    });

    test('forceUnsynchronized resets state', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.synchronized));

      sm.forceUnsynchronized();
      expect(sm.currentState, equals(SyncState.unsynchronized));
    });

    test('reset with new generation resets state', () {
      final sm = SyncStateMachine();
      sm.reset(generation: 1);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      sm.evaluate(validSampleCount: 3, currentUncertaintyNs: 5_000_000, hasUsableEstimate: true);
      expect(sm.currentState, equals(SyncState.synchronized));

      sm.reset(generation: 2);
      expect(sm.currentState, equals(SyncState.unsynchronized));
    });
  });

  group('SyncStatus', () {
    test('fromEstimate creates correct status', () {
      final estimate = SyncEstimate(offsetNs: 5_000_000, rttNs: 10_000_000, uncertaintyNs: 5_000_000);
      final status = SyncStatus.fromEstimate(
        estimate: estimate,
        state: SyncState.synchronized,
        generation: 1,
        validSampleCount: 3,
      );
      expect(status.state, equals(SyncState.synchronized));
      expect(status.offsetMs, equals(5.0));
      expect(status.rttMs, equals(10.0));
      expect(status.uncertaintyMs, equals(5.0));
      expect(status.generation, equals(1));
      expect(status.validSampleCount, equals(3));
    });

    test('unsynchronized factory creates correct status', () {
      final status = SyncStatus.unsynchronized(generation: 1);
      expect(status.state, equals(SyncState.unsynchronized));
      expect(status.offsetMs, isNull);
      expect(status.rttMs, isNull);
      expect(status.uncertaintyMs, isNull);
      expect(status.generation, equals(1));
      expect(status.validSampleCount, equals(0));
    });

    test('toJson includes all fields', () {
      final status = SyncStatus.fromEstimate(
        estimate: SyncEstimate(offsetNs: 5_000_000, rttNs: 10_000_000, uncertaintyNs: 5_000_000),
        state: SyncState.synchronized,
        generation: 1,
        validSampleCount: 3,
      );
      final json = status.toJson();
      expect(json['state'], equals('SYNCHRONIZED'));
      expect(json['offsetMs'], equals(5.0));
      expect(json['rttMs'], equals(10.0));
      expect(json['uncertaintyMs'], equals(5.0));
      expect(json['generation'], equals(1));
      expect(json['validSampleCount'], equals(3));
    });
  });
}