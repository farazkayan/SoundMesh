import 'package:soundmesh/src/soundmesh_messages.g.dart';

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
