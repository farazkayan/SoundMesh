import 'package:soundmesh/src/soundmesh_messages.g.dart';

abstract class CaptureRepository {
  Future<CapturePermissionResult> requestCapturePermission();
  Future<CaptureResult> startCapture();
  Future<void> stopCapture();
  Future<CaptureStateResult> getCaptureState();
  Future<bool> isIgnoringBatteryOptimizations();
  Future<void> requestIgnoreBatteryOptimizations();
  // Phase 8: Audio streaming
  Future<void> startStreaming();
  Future<void> stopStreaming();
  Future<StreamingState> getStreamingState();
}

class LiveCaptureRepository implements CaptureRepository {
  final AudioCapturePlatform _platform;

  LiveCaptureRepository() : _platform = AudioCapturePlatform();

  @override
  Future<CapturePermissionResult> requestCapturePermission() async {
    return _platform.requestCapturePermission();
  }

  @override
  Future<CaptureResult> startCapture() async {
    return _platform.startCapture();
  }

  @override
  Future<void> stopCapture() async {
    return _platform.stopCapture();
  }

  @override
  Future<CaptureStateResult> getCaptureState() async {
    return _platform.getCaptureState();
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    return _platform.isIgnoringBatteryOptimizations();
  }

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    return _platform.requestIgnoreBatteryOptimizations();
  }

  @override
  Future<void> startStreaming() async {
    return _platform.startStreaming();
  }

  @override
  Future<void> stopStreaming() async {
    return _platform.stopStreaming();
  }

  @override
  Future<StreamingState> getStreamingState() async {
    return _platform.getStreamingState();
  }
}