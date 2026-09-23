import 'offset_estimator.dart';
import 'sample_history.dart';

class OutlierFilterResult {
  final bool valid;
  final String? rejectionReason;

  OutlierFilterResult({required this.valid, this.rejectionReason});

  @override
  String toString() => 'OutlierFilterResult(valid: $valid, reason: $rejectionReason)';
}

class OutlierFilter {
  static const int _minSamplesForMedianFilter = 5;

  static OutlierFilterResult validate({
    required int t1,
    required int t2,
    required int t3,
    required int t4,
    required int generation,
    required int currentGeneration,
    List<SyncSample>? recentSamples,
  }) {
    if (generation != currentGeneration) {
      return OutlierFilterResult(valid: false, rejectionReason: 'stale generation');
    }

    if (!OffsetEstimator.isValidOrdering(t1: t1, t2: t2, t3: t3, t4: t4)) {
      if (t4 < t1) {
        return OutlierFilterResult(valid: false, rejectionReason: 'receive before send (t4 < t1)');
      }
      if (t3 < t2) {
        return OutlierFilterResult(valid: false, rejectionReason: 'host send before receive (t3 < t2)');
      }
      return OutlierFilterResult(valid: false, rejectionReason: 'invalid timestamp ordering');
    }

    final rtt = OffsetEstimator.computeRtt(t1: t1, t2: t2, t3: t3, t4: t4);
    if (!OffsetEstimator.isValidRtt(rtt)) {
      return OutlierFilterResult(valid: false, rejectionReason: 'invalid RTT (RTT <= 0)');
    }

    if (recentSamples != null && recentSamples.length >= _minSamplesForMedianFilter) {
      final validSamples = recentSamples.where((s) => s.valid).toList();
      if (validSamples.length >= _minSamplesForMedianFilter) {
        final medianRtt = _computeMedian(validSamples.map((s) => s.rttNs).toList());
        if (rtt > 3 * medianRtt) {
          return OutlierFilterResult(valid: false, rejectionReason: 'RTT outlier (rtt > 3 * medianRTT)');
        }

        final medianOffset = _computeMedian(validSamples.map((s) => s.offsetNs).toList());
        final mad = _computeMAD(validSamples.map((s) => s.offsetNs).toList(), medianOffset);
        final offset = OffsetEstimator.computeOffset(t1: t1, t2: t2, t3: t3, t4: t4);
        if (mad > 0 && (offset - medianOffset).abs() > 3 * mad) {
          return OutlierFilterResult(valid: false, rejectionReason: 'offset outlier (|offset - median| > 3 * MAD)');
        }
      }
    }

    return OutlierFilterResult(valid: true);
  }

  static int _computeMedian(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[mid - 1] + sorted[mid]) ~/ 2;
    }
    return sorted[mid];
  }

  static int _computeMAD(List<int> values, int median) {
    if (values.isEmpty) return 0;
    final deviations = values.map((v) => (v - median).abs()).toList();
    return _computeMedian(deviations);
  }
}