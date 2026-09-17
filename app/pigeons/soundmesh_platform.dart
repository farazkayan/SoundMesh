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

class CaptureState {
  final String state;
  CaptureState({required this.state});
}

class CaptureMetadata {
  final String sessionId;
  final int generation;
  final int sampleRate;
  final int channelCount;
  final int startedAtNanos;
  CaptureMetadata({
    required this.sessionId,
    required this.generation,
    required this.sampleRate,
    required this.channelCount,
    required this.startedAtNanos,
  });
}

class CaptureError {
  final String code;
  final String message;
  CaptureError({required this.code, required this.message});
}

class CapturePermissionResult {
  final String result;
  final CaptureError? error;
  CapturePermissionResult({required this.result, this.error});
}

class CaptureResult {
  final bool success;
  final CaptureMetadata? metadata;
  final CaptureError? error;
  CaptureResult({required this.success, this.metadata, this.error});
}

class CaptureStateResult {
  final CaptureState state;
  final CaptureMetadata? metadata;
  CaptureStateResult({required this.state, this.metadata});
}

@HostApi()
abstract class NetworkHostPlatform {
  bool startHosting(int port);
  bool connectToHost(String ipAddress, int port);
  bool sendMessage(String message);
  bool sendChatMessage(String text);
  bool sendProtocolMessage(String message);
  void disconnect();
  String getLocalIpAddress();
  void setHeartbeatConfig(int intervalMs, int timeoutMs);
  bool reconnectToHost(String ipAddress, int port);
}

@HostApi()
abstract class DevicePlatform {
  DeviceInfo getDeviceInfo();
}

@HostApi()
abstract class TimingPlatform {
  int getMonotonicTimeNanos();
}

@HostApi()
abstract class AudioCapturePlatform {
  @async
  CapturePermissionResult requestCapturePermission();
  @async
  CaptureResult startCapture();
  @async
  void stopCapture();
  CaptureStateResult getCaptureState();
}

@FlutterApi()
abstract class NetworkFlutterApi {
  void onMessageReceived(String message);
  void onConnectionStateChanged(String state);
  void onConnectionError(String errorCode, String errorMessage);
}

@FlutterApi()
abstract class AudioCaptureFlutterApi {
  void onCaptureStateChanged(String state, CaptureMetadata? metadata);
  void onCaptureError(String errorCode, String errorMessage);
}