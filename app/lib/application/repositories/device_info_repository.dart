import 'package:soundmesh/src/device_messages.g.dart';

abstract class DeviceInfoRepository {
  Future<DeviceInfo> getDeviceInfo();
}

class LiveDeviceInfoRepository implements DeviceInfoRepository {
  final DevicePlatform _platform;

  LiveDeviceInfoRepository() : _platform = DevicePlatform();

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    return _platform.getDeviceInfo();
  }
}
