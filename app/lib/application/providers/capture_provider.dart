import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/soundmesh_messages.g.dart';
import '../repositories/capture_repository.dart';

enum CaptureUiState {
  idle,
  requestingPermission,
  permissionGranted,
  permissionDenied,
  capturing,
  stopped,
  failed,
}

class CaptureUiStateData {
  final CaptureUiState state;
  final CaptureMetadata? metadata;
  final CaptureError? error;
  final FrameArrivalStats? frameStats;
  final bool? isIgnoringBatteryOptimizations;
  // Phase 8: Streaming state
  final StreamingMetadata? streamingMetadata;
  final String? streamState;
  final CaptureError? streamError;

  const CaptureUiStateData({
    this.state = CaptureUiState.idle,
    this.metadata,
    this.error,
    this.frameStats,
    this.isIgnoringBatteryOptimizations,
    this.streamingMetadata,
    this.streamState,
    this.streamError,
  });

  CaptureUiStateData copyWith({
    CaptureUiState? state,
    CaptureMetadata? metadata,
    CaptureError? error,
    FrameArrivalStats? frameStats,
    bool? isIgnoringBatteryOptimizations,
    StreamingMetadata? streamingMetadata,
    String? streamState,
    CaptureError? streamError,
  }) {
    return CaptureUiStateData(
      state: state ?? this.state,
      metadata: metadata ?? this.metadata,
      error: error ?? this.error,
      frameStats: frameStats ?? this.frameStats,
      isIgnoringBatteryOptimizations: isIgnoringBatteryOptimizations ?? this.isIgnoringBatteryOptimizations,
      streamingMetadata: streamingMetadata ?? this.streamingMetadata,
      streamState: streamState ?? this.streamState,
      streamError: streamError ?? this.streamError,
    );
  }
}

class CaptureStateNotifier extends StateNotifier<CaptureUiStateData> with WidgetsBindingObserver {
  final CaptureRepository _repository;
  bool _isListening = false;
  bool _batteryOptimizationChecked = false;

  CaptureStateNotifier(this._repository) : super(const CaptureUiStateData()) {
    _startListening();
    _refreshState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[BatteryOptimization] App resumed - re-checking status');
      _batteryOptimizationChecked = false; // Allow re-check
      _checkBatteryOptimization();
    }
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;

    AudioCaptureFlutterApi.setUp(_CaptureFlutterApiImpl(this));
  }

  void _refreshState() async {
    try {
      final result = await _repository.getCaptureState();
      _mapState(result);
    } catch (e) {
      debugPrint('[Capture] Failed to get initial state: $e');
    }
    // Check battery optimization status once on startup
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    if (_batteryOptimizationChecked) {
      debugPrint('[BatteryOptimization] Already checked, skipping');
      return;
    }
    _batteryOptimizationChecked = true;
    try {
      debugPrint('[BatteryOptimization] Checking status via platform channel...');
      final isIgnoring = await _repository.isIgnoringBatteryOptimizations();
      debugPrint('[BatteryOptimization] Platform returned: $isIgnoring');
      state = state.copyWith(isIgnoringBatteryOptimizations: isIgnoring);
    } catch (e) {
      debugPrint('[BatteryOptimization] Failed to check battery optimization: $e');
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    debugPrint('[BatteryOptimization] Button pressed - requesting ignore battery optimizations');
    try {
      await _repository.requestIgnoreBatteryOptimizations();
      debugPrint('[BatteryOptimization] Repository call returned, waiting to re-check');
      // After the user responds to the system dialog, re-check status
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[BatteryOptimization] Re-checking battery optimization status');
      await _checkBatteryOptimization();
    } catch (e) {
      debugPrint('[BatteryOptimization] Failed to request battery optimization exemption: $e');
    }
  }

  void _mapState(CaptureStateResult result) {
    final uiState = parseState(result.state.state);
    state = state.copyWith(
      state: uiState,
      metadata: result.metadata,
      error: null,
    );
  }

  // Public methods for FlutterApi callbacks
  void handleStateChanged(String stateStr, CaptureMetadata? metadata) {
    final uiState = parseState(stateStr);
    state = state.copyWith(
      state: uiState,
      metadata: metadata,
      error: null,
    );
  }

  void handleFrameStats(FrameArrivalStats stats) {
    state = state.copyWith(frameStats: stats);
  }

  void handleError(String code, String message) {
    state = state.copyWith(
      state: CaptureUiState.failed,
      error: CaptureError(code: code, message: message),
    );
  }

  void handleStreamStateChanged(String streamState, StreamingMetadata? metadata) {
    state = state.copyWith(
      streamState: streamState,
      streamingMetadata: metadata,
      streamError: null,
    );
  }

  void handleStreamError(String code, String message) {
    state = state.copyWith(
      streamState: 'FAILED',
      streamError: CaptureError(code: code, message: message),
    );
  }

  CaptureUiState parseState(String state) {
    switch (state) {
      case 'IDLE':
        return CaptureUiState.idle;
      case 'REQUESTING_PERMISSION':
        return CaptureUiState.requestingPermission;
      case 'PERMISSION_GRANTED':
        return CaptureUiState.permissionGranted;
      case 'PERMISSION_DENIED':
        return CaptureUiState.permissionDenied;
      case 'CAPTURING':
        return CaptureUiState.capturing;
      case 'STOPPED':
        return CaptureUiState.stopped;
      case 'FAILED':
        return CaptureUiState.failed;
      default:
        return CaptureUiState.idle;
    }
  }

  Future<void> requestPermission() async {
    state = state.copyWith(state: CaptureUiState.requestingPermission, error: null);
    try {
      final result = await _repository.requestCapturePermission();
      if (result.result == 'GRANTED') {
        // State will be updated via native callback
        debugPrint('[Capture] Permission granted');
      } else {
        state = state.copyWith(
          state: CaptureUiState.permissionDenied,
          error: result.error,
        );
      }
    } catch (e) {
      state = state.copyWith(
        state: CaptureUiState.failed,
        error: CaptureError(code: 'ERROR', message: e.toString()),
      );
    }
  }

  Future<void> start() async {
    try {
      final result = await _repository.startCapture();
      if (!result.success) {
        state = state.copyWith(
          state: CaptureUiState.failed,
          error: result.error,
        );
      }
      // Success state updated via native callback
    } catch (e) {
      state = state.copyWith(
        state: CaptureUiState.failed,
        error: CaptureError(code: 'ERROR', message: e.toString()),
      );
    }
  }

  Future<void> stop() async {
    try {
      await _repository.stopCapture();
      // State updated via native callback
    } catch (e) {
      state = state.copyWith(
        state: CaptureUiState.failed,
        error: CaptureError(code: 'ERROR', message: e.toString()),
      );
    }
  }

  Future<void> startCaptureAndStream() async {
    try {
      final result = await _repository.startCapture();
      if (!result.success) {
        state = state.copyWith(
          state: CaptureUiState.failed,
          error: result.error,
        );
        return;
      }
      await _repository.startStreaming();
    } catch (e) {
      state = state.copyWith(
        state: CaptureUiState.failed,
        error: CaptureError(code: 'ERROR', message: e.toString()),
      );
    }
  }

  Future<void> stopStreamingAndCapture() async {
    try {
      await _repository.stopStreaming();
      await _repository.stopCapture();
    } catch (e) {
      state = state.copyWith(
        state: CaptureUiState.failed,
        error: CaptureError(code: 'ERROR', message: e.toString()),
      );
    }
  }

  bool get isStreaming => state.streamState == 'STREAMING';

  Future<void> refresh() async {
    _refreshState();
  }

  @override
  void dispose() {
    AudioCaptureFlutterApi.setUp(null);
    WidgetsBinding.instance.removeObserver(this);
    _isListening = false;
    super.dispose();
  }
}

class _CaptureFlutterApiImpl implements AudioCaptureFlutterApi {
  final CaptureStateNotifier _notifier;

  _CaptureFlutterApiImpl(this._notifier);

  @override
  void onCaptureStateChanged(String state, CaptureMetadata? metadata) {
    debugPrint('[Capture] Native state change: $state');
    _notifier.handleStateChanged(state, metadata);
  }

  @override
  void onCaptureError(String errorCode, String errorMessage) {
    debugPrint('[Capture] Native error: $errorCode - $errorMessage');
    _notifier.handleError(errorCode, errorMessage);
  }

  @override
  void onCaptureFramesReceived(FrameArrivalStats stats) {
    debugPrint('[Capture] Frame stats: ${stats.totalFrames} frames, ${stats.framesPerSecond} fps');
    _notifier.handleFrameStats(stats);
  }

  @override
  void onStreamStateChanged(String state, StreamingMetadata? metadata) {
    debugPrint('[Capture] Stream state change: $state');
    _notifier.handleStreamStateChanged(state, metadata);
  }

  @override
  void onStreamError(String errorCode, String errorMessage) {
    debugPrint('[Capture] Stream error: $errorCode - $errorMessage');
    _notifier.handleStreamError(errorCode, errorMessage);
  }
}

final captureRepositoryProvider = Provider<CaptureRepository>((ref) {
  return LiveCaptureRepository();
});

final captureStateProvider = StateNotifierProvider<CaptureStateNotifier, CaptureUiStateData>((ref) {
  final repo = ref.watch(captureRepositoryProvider);
  return CaptureStateNotifier(repo);
});