import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/soundmesh_messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/soundmesh/soundmesh/SoundMeshMessages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.soundmesh.soundmesh'),
    swiftOut: 'ios/Runner/SoundMeshMessages.g.swift',
    swiftOptions: SwiftOptions(),
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'soundmesh',
  ),
)

class ConnectionState {
  final String state;
  ConnectionState({required this.state});
}

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
abstract class NetworkHostPlatform {
  bool startHosting(int port);
  bool connectToHost(String ipAddress, int port);
  bool sendMessage(String message);
  void disconnect();
  String getLocalIpAddress();
}

@HostApi()
abstract class DevicePlatform {
  DeviceInfo getDeviceInfo();
}

@HostApi()
abstract class TimingPlatform {
  int getMonotonicTimeNanos();
}

@FlutterApi()
abstract class NetworkFlutterApi {
  void onMessageReceived(String message);
  void onConnectionStateChanged(String state);
  void onConnectionError(String errorCode, String errorMessage);
}