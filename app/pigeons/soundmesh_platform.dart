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

class FrameArrivalStats {
  final int totalFrames;
  final int totalBytes;
  final int silentFrames;
  final int framesPerSecond;
  final int bytesPerSecond;
  final int timestampNanos;
  final bool isReceivingAudio;
  final int peakAmplitude;
  final bool isSilent;
  FrameArrivalStats({
    required this.totalFrames,
    required this.totalBytes,
    required this.silentFrames,
    required this.framesPerSecond,
    required this.bytesPerSecond,
    required this.timestampNanos,
    required this.isReceivingAudio,
    required this.peakAmplitude,
    required this.isSilent,
  });
}

class StreamingMetadata {
  final String sessionId;
  final int generation;
  final int sampleRate;
  final int channelCount;
  final int startedAtNanos;
  StreamingMetadata({
    required this.sessionId,
    required this.generation,
    required this.sampleRate,
    required this.channelCount,
    required this.startedAtNanos,
  });
}

class StreamingState {
  final String state;
  final StreamingMetadata? metadata;
  StreamingState({required this.state, this.metadata});
}

class ReceiveStats {
  final int packetsReceived;
  final int packetsLost;
  final int packetsOutOfOrder;
  final int bufferDepthMs;
  final double lossRate;
  final int timestampNanos;
  final bool isHealthy;
  final int peakAmplitude;
  final bool isSilent;
  ReceiveStats({
    required this.packetsReceived,
    required this.packetsLost,
    required this.packetsOutOfOrder,
    required this.bufferDepthMs,
    required this.lossRate,
    required this.timestampNanos,
    required this.isHealthy,
    this.peakAmplitude = 0,
    this.isSilent = true,
  });
}

class ReceiveState {
  final String state;
  final ReceiveStats? stats;
  ReceiveState({required this.state, this.stats});
}

class OutputState {
  final String state;
  final int bufferedMs;
  OutputState({required this.state, required this.bufferedMs});
}

class OutputError {
  final String code;
  final String message;
  OutputError({required this.code, required this.message});
}

@HostApi()
abstract class AudioOutputPlatform {
  OutputState getOutputState();
  ScheduleResult scheduleFrame(int framePosition, int targetNativeTimeNanos, int generation);
}

class ScheduleResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;
  ScheduleResult({required this.success, this.errorCode, this.errorMessage});
}

@FlutterApi()
abstract class AudioOutputFlutterApi {
  void onOutputStateChanged(String state, int bufferedMs);
  void onOutputError(String errorCode, String errorMessage);
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
  @async
  void setHeartbeatConfig(int intervalMs, int timeoutMs);
  @async
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
  bool isIgnoringBatteryOptimizations();
  @async
  void requestIgnoreBatteryOptimizations();
  @async
  void startStreaming();
  @async
  void stopStreaming();
  StreamingState getStreamingState();
}

@HostApi()
abstract class AudioReceivePlatform {
  ReceiveState getReceiveState();
  NextFrameInfo? getNextFrameInfo();
}

class NextFrameInfo {
  final int framePosition;
  final int sequenceNumber;
  final int generation;
  final int sampleRate;
  final int channelCount;
  NextFrameInfo({
    required this.framePosition,
    required this.sequenceNumber,
    required this.generation,
    required this.sampleRate,
    required this.channelCount,
  });
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
  void onCaptureFramesReceived(FrameArrivalStats stats);
  void onStreamStateChanged(String state, StreamingMetadata? metadata);
  void onStreamError(String errorCode, String errorMessage);
}

@FlutterApi()
abstract class AudioReceiveFlutterApi {
  void onStreamStateChanged(String state, ReceiveStats? stats);
  void onAudioLevelUpdate(int peakAmplitude, bool isSilent);
}

class PipelineError {
  final String code;
  final String message;
  final int generation;
  PipelineError({required this.code, required this.message, required this.generation});
}

class TimeSyncResponse {
  final int t1;
  final int t2;
  final int t3;
  final int generation;
  final String sessionId;
  final String senderId;
  TimeSyncResponse({
    required this.t1,
    required this.t2,
    required this.t3,
    required this.generation,
    required this.sessionId,
    required this.senderId,
  });
}

class DriftStatus {
  final String state;
  final double? driftMsPerSecond;
  final double? confidence;
  final int generation;
  final int validSampleCount;
  final int timeSpanNs;
  DriftStatus({
    required this.state,
    this.driftMsPerSecond,
    this.confidence,
    required this.generation,
    required this.validSampleCount,
    required this.timeSpanNs,
  });
}

@FlutterApi()
abstract class DriftFlutterApi {
  void onDriftStatusChanged(DriftStatus status);
}

@FlutterApi()
abstract class PipelineFlutterApi {
  void onPipelineStateChanged(String state, int generation);
  void onPipelineError(PipelineError error);
  void onTimeSyncResponse(TimeSyncResponse response);
  void onSyncStateChanged(String state, int generation);
}

@HostApi()
abstract class PipelinePlatform {
  @async
  void startPipeline();
  @async
  void stopPipeline();
  int getPipelineGeneration();
  String getPipelineState();
  String getSyncState();
  void updateSyncState(String state, int generation, double offsetMs, double? driftMsPerSecond);
}