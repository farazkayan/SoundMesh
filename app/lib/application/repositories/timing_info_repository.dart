import 'package:soundmesh/src/soundmesh_messages.g.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class TimingInfoRepository {
  Future<int> getMonotonicTimeNanos();
}

class LiveTimingInfoRepository implements TimingInfoRepository {
  final TimingPlatform _platform;

  LiveTimingInfoRepository() : _platform = TimingPlatform();

  @override
  Future<int> getMonotonicTimeNanos() async {
    return _platform.getMonotonicTimeNanos();
  }
}

final timingInfoRepositoryProvider = Provider<TimingInfoRepository>((ref) {
  final repo = LiveTimingInfoRepository();
  return repo;
});
