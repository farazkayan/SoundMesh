class SyncEstimate {
  final int offsetNs;
  final int rttNs;
  final int uncertaintyNs;

  SyncEstimate({
    required this.offsetNs,
    required this.rttNs,
    required this.uncertaintyNs,
  });

  @override
  String toString() =>
      'SyncEstimate(offsetNs: $offsetNs, rttNs: $rttNs, uncertaintyNs: $uncertaintyNs)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncEstimate &&
          runtimeType == other.runtimeType &&
          offsetNs == other.offsetNs &&
          rttNs == other.rttNs &&
          uncertaintyNs == other.uncertaintyNs;

  @override
  int get hashCode => Object.hash(offsetNs, rttNs, uncertaintyNs);
}

class OffsetEstimator {
  static SyncEstimate compute({
    required int t1,
    required int t2,
    required int t3,
    required int t4,
  }) {
    final int rtt = computeRtt(t1: t1, t2: t2, t3: t3, t4: t4);
    final int offset = computeOffset(t1: t1, t2: t2, t3: t3, t4: t4);
    final int uncertainty = computeUncertainty(rtt: rtt);

    return SyncEstimate(
      offsetNs: offset,
      rttNs: rtt,
      uncertaintyNs: uncertainty,
    );
  }

  static int computeRtt({
    required int t1,
    required int t2,
    required int t3,
    required int t4,
  }) {
    return (t4 - t1) - (t3 - t2);
  }

  static int computeOffset({
    required int t1,
    required int t2,
    required int t3,
    required int t4,
  }) {
    return ((t2 - t1) + (t3 - t4)) ~/ 2;
  }

  static int computeUncertainty({required int rtt}) {
    return rtt ~/ 2;
  }

  static bool isValidOrdering({
    required int t1,
    required int t2,
    required int t3,
    required int t4,
  }) {
    return t4 >= t1 && t3 >= t2;
  }

  static bool isValidRtt(int rtt) {
    return rtt > 0;
  }
}