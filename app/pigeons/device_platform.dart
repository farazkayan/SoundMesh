import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/device_messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/soundmesh/soundmesh/DeviceMessages.g.kt',
    kotlinOptions: KotlinOptions(),
    swiftOut: 'ios/Runner/DeviceMessages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'soundmesh',
  ),
)
class DeviceInfo {
  String platformName;
  String osVersion;
  String deviceModel;
  String? brand;
  DeviceInfo({
    required this.platformName,
    required this.osVersion,
    required this.deviceModel,
    this.brand,
  });
}

@HostApi()
abstract class DevicePlatform {
  DeviceInfo getDeviceInfo();
}
