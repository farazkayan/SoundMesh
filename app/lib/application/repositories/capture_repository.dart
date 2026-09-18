import 'package:soundmesh/src/soundmesh_messages.g.dart';

abstract class CaptureRepository {
  Future<CapturePermissionResult> requestCapturePermission();
  Future<CaptureResult> startCapture();
  Future<void> stopCapture();
  Future<CaptureStateResult> getCaptureState();
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
}