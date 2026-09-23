import 'offset_estimator.dart';

class SyncSample {
  final int t1;
  final int t2;
  final int t3;
  final int t4;
  final int rttNs;
  final int offsetNs;
  final int uncertaintyNs;
  final int generation;
  final int receivedAtNs;
  final bool valid;
  final String? rejectionReason;

  SyncSample({
    required this.t1,
    required this.t2,
    required this.t3,
    required this.t4,
    required this.rttNs,
    required this.offsetNs,
    required this.uncertaintyNs,
    required this.generation,
    required this.receivedAtNs,
    this.valid = true,
    this.rejectionReason,
  });

  SyncSample.fromExchange({
    required this.t1,
    required this.t2,
    required this.t3,
    required this.t4,
    required this.generation,
    required this.receivedAtNs,
    required this.valid,
    this.rejectionReason,
  })  : rttNs = OffsetEstimator.computeRtt(t1: t1, t2: t2, t3: t3, t4: t4),
        offsetNs = OffsetEstimator.computeOffset(t1: t1, t2: t2, t3: t3, t4: t4),
        uncertaintyNs = OffsetEstimator.computeUncertainty(rtt: OffsetEstimator.computeRtt(t1: t1, t2: t2, t3: t3, t4: t4));

  @override
  String toString() =>
      'SyncSample(t1:$t1 t2:$t2 t3:$t3 t4:$t4 rtt:${rttNs}ns offset:${offsetNs}ns uncertainty:${uncertaintyNs}ns gen:$generation valid:$valid reason:$rejectionReason)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncSample &&
          runtimeType == other.runtimeType &&
          t1 == other.t1 &&
          t2 == other.t2 &&
          t3 == other.t3 &&
          t4 == other.t4 &&
          generation == other.generation &&
          receivedAtNs == other.receivedAtNs;

  @override
  int get hashCode => Object.hash(t1, t2, t3, t4, generation, receivedAtNs);
}

class SampleHistory {
  final int _maxSamples;
  final List<SyncSample> _samples = [];

  SampleHistory({this._maxSamples = 20});

  void addSample(SyncSample sample) {
    _samples.add(sample);
    if (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
  }

  List<SyncSample> getValidSamples({required int currentGeneration, int maxAgeNs = 10_000_000_000}) {
    final now = DateTime.now().microsecondsSinceEpoch * 1000;
    return _samples.where((s) {
      if (!s.valid) return false;
      if (s.generation != currentGeneration) return false;
      if (now - s.receivedAtNs > maxAgeNs) return false;
      return true;
    }).toList();
  }

  List<SyncSample> getAllSamples() => List.unmodifiable(_samples);

  SyncSample? getBestSample({required int currentGeneration}) {
    final valid = getValidSamples(currentGeneration: currentGeneration);
    if (valid.isEmpty) return null;

    valid.sort((a, b) => a.uncertaintyNs.compareTo(b.uncertaintyNs));
    return valid.first;
  }

  SyncEstimate? getCurrentEstimate({required int currentGeneration}) {
    final best = getBestSample(currentGeneration: currentGeneration);
    if (best == null) return null;

    return SyncEstimate(
      offsetNs: best.offsetNs,
      rttNs: best.rttNs,
      uncertaintyNs: best.uncertaintyNs,
    );
  }

  int getValidSampleCount({required int currentGeneration}) {
    return getValidSamples(currentGeneration: currentGeneration).length;
  }

  void clear() => _samples.clear();
}