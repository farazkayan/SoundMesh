import 'offset_estimator.dart';

enum SyncState {
  unsynchronized,
  synchronizing,
  synchronized,
  degraded,
}

extension SyncStateX on SyncState {
  String get wireValue {
    switch (this) {
      case SyncState.unsynchronized:
        return 'UNSYNCHRONIZED';
      case SyncState.synchronizing:
        return 'SYNCHRONIZING';
      case SyncState.synchronized:
        return 'SYNCHRONIZED';
      case SyncState.degraded:
        return 'DEGRADED';
    }
  }

  static SyncState fromWireValue(String value) {
    switch (value) {
      case 'UNSYNCHRONIZED':
        return SyncState.unsynchronized;
      case 'SYNCHRONIZING':
        return SyncState.synchronizing;
      case 'SYNCHRONIZED':
        return SyncState.synchronized;
      case 'DEGRADED':
        return SyncState.degraded;
      default:
        return SyncState.unsynchronized;
    }
  }
}

class SyncStatus {
  final SyncState state;
  final double? offsetMs;
  final double? rttMs;
  final double? uncertaintyMs;
  final int lastMeasurementNs;
  final int generation;
  final int validSampleCount;

  SyncStatus({
    required this.state,
    this.offsetMs,
    this.rttMs,
    this.uncertaintyMs,
    required this.lastMeasurementNs,
    required this.generation,
    required this.validSampleCount,
  });

  factory SyncStatus.fromEstimate({
    required SyncEstimate estimate,
    required SyncState state,
    required int generation,
    required int validSampleCount,
  }) {
    return SyncStatus(
      state: state,
      offsetMs: estimate.offsetNs / 1_000_000.0,
      rttMs: estimate.rttNs / 1_000_000.0,
      uncertaintyMs: estimate.uncertaintyNs / 1_000_000.0,
      lastMeasurementNs: DateTime.now().microsecondsSinceEpoch * 1000,
      generation: generation,
      validSampleCount: validSampleCount,
    );
  }

  factory SyncStatus.unsynchronized({required int generation}) {
    return SyncStatus(
      state: SyncState.unsynchronized,
      lastMeasurementNs: DateTime.now().microsecondsSinceEpoch * 1000,
      generation: generation,
      validSampleCount: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state.wireValue,
      'offsetMs': offsetMs,
      'rttMs': rttMs,
      'uncertaintyMs': uncertaintyMs,
      'lastMeasurementNs': lastMeasurementNs,
      'generation': generation,
      'validSampleCount': validSampleCount,
    };
  }

  @override
  String toString() =>
      'SyncStatus(state: ${state.wireValue}, offsetMs: $offsetMs, rttMs: $rttMs, uncertaintyMs: $uncertaintyMs, gen: $generation, samples: $validSampleCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          offsetMs == other.offsetMs &&
          rttMs == other.rttMs &&
          uncertaintyMs == other.uncertaintyMs &&
          lastMeasurementNs == other.lastMeasurementNs &&
          generation == other.generation &&
          validSampleCount == other.validSampleCount;

  @override
  int get hashCode => Object.hash(
    state,
    offsetMs,
    rttMs,
    uncertaintyMs,
    lastMeasurementNs,
    generation,
    validSampleCount,
  );
}

class SyncStateMachine {
  static const int _syncThresholdSamples = 3;
  static const int _syncUncertaintyThresholdNs = 5_000_000;
  static const int _degradedUncertaintyThresholdNs = 20_000_000;

  SyncState currentState = SyncState.unsynchronized;
  int currentGeneration = 0;

  SyncState evaluate({
    required int validSampleCount,
    required int? currentUncertaintyNs,
    required bool hasUsableEstimate,
  }) {
    if (!hasUsableEstimate || validSampleCount == 0) {
      currentState = SyncState.unsynchronized;
      return currentState;
    }

    final uncertainty = currentUncertaintyNs ?? 0;

    switch (currentState) {
      case SyncState.unsynchronized:
        currentState = SyncState.synchronizing;
        break;
      case SyncState.synchronizing:
        if (validSampleCount >= _syncThresholdSamples && uncertainty <= _syncUncertaintyThresholdNs) {
          currentState = SyncState.synchronized;
        } else if (uncertainty > _degradedUncertaintyThresholdNs) {
          currentState = SyncState.degraded;
        }
        break;
      case SyncState.synchronized:
        if (uncertainty > _degradedUncertaintyThresholdNs) {
          currentState = SyncState.degraded;
        }
        break;
      case SyncState.degraded:
        if (validSampleCount >= _syncThresholdSamples && uncertainty <= _syncUncertaintyThresholdNs) {
          currentState = SyncState.synchronized;
        }
        break;
    }

    return currentState;
  }

  void reset({required int generation}) {
    currentState = SyncState.unsynchronized;
    currentGeneration = generation;
  }

  void forceUnsynchronized() {
    currentState = SyncState.unsynchronized;
  }
}