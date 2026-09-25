import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/soundmesh_messages.g.dart';

enum OutputUiState {
  idle,
  starting,
  playing,
  underrun,
  stopped,
  failed,
}

class OutputUiStateData {
  final OutputUiState state;
  final int bufferedMs;
  final String? error;

  const OutputUiStateData({
    this.state = OutputUiState.idle,
    this.bufferedMs = 0,
    this.error,
  });

  OutputUiStateData copyWith({
    OutputUiState? state,
    int? bufferedMs,
    String? error,
  }) {
    return OutputUiStateData(
      state: state ?? this.state,
      bufferedMs: bufferedMs ?? this.bufferedMs,
      error: error ?? this.error,
    );
  }
}

class OutputStateNotifier extends StateNotifier<OutputUiStateData> with WidgetsBindingObserver {
  bool _isListening = false;

  OutputStateNotifier() : super(const OutputUiStateData()) {
    _startListening();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No special handling needed for output on lifecycle changes
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;

    AudioOutputFlutterApi.setUp(_OutputFlutterApiImpl(this));
  }

  void handleOutputStateChanged(String stateStr, int bufferedMs) {
    debugPrint('[Output] Native output state change: $stateStr, bufferedMs: $bufferedMs');
    final uiState = _parseState(stateStr);
    state = state.copyWith(
      state: uiState,
      bufferedMs: bufferedMs,
      error: null,
    );
  }

  void handleError(String code, String message) {
    debugPrint('[Output] Native error: $code - $message');
    state = state.copyWith(
      state: OutputUiState.failed,
      error: '$code: $message',
    );
  }

  OutputUiState _parseState(String state) {
    switch (state) {
      case 'IDLE':
        return OutputUiState.idle;
      case 'STARTING':
        return OutputUiState.starting;
      case 'PLAYING':
        return OutputUiState.playing;
      case 'UNDERRUN':
        return OutputUiState.underrun;
      case 'STOPPED':
        return OutputUiState.stopped;
      case 'ROUTE_CHANGED':
        // Route changed is informational, don't change main state
        return _parseState('PLAYING'); // Return current playing state
      case 'ERROR':
        return OutputUiState.failed;
      default:
        return OutputUiState.idle;
    }
  }

  @override
  void dispose() {
    AudioOutputFlutterApi.setUp(null);
    WidgetsBinding.instance.removeObserver(this);
    _isListening = false;
    super.dispose();
  }
}

class _OutputFlutterApiImpl implements AudioOutputFlutterApi {
  final OutputStateNotifier _notifier;

  _OutputFlutterApiImpl(this._notifier);

  @override
  void onOutputStateChanged(String state, int bufferedMs) {
    _notifier.handleOutputStateChanged(state, bufferedMs);
  }

  @override
  void onOutputError(String errorCode, String errorMessage) {
    _notifier.handleError(errorCode, errorMessage);
  }

  @override
  void requestScheduleTarget(int framePosition, int captureTimestampNs, int generation) {
    // Not used in current architecture - Dart drives scheduling via scheduleFrame()
  }
}

final outputStateProvider = StateNotifierProvider<OutputStateNotifier, OutputUiStateData>((ref) {
  return OutputStateNotifier();
});