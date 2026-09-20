import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/soundmesh_messages.g.dart';

enum ReceiveUiState {
  idle,
  receiving,
  stopped,
  failed,
}

class ReceiveUiStateData {
  final ReceiveUiState state;
  final ReceiveStats? stats;
  final String? error;

  const ReceiveUiStateData({
    this.state = ReceiveUiState.idle,
    this.stats,
    this.error,
  });

  ReceiveUiStateData copyWith({
    ReceiveUiState? state,
    ReceiveStats? stats,
    String? error,
  }) {
    return ReceiveUiStateData(
      state: state ?? this.state,
      stats: stats ?? this.stats,
      error: error ?? this.error,
    );
  }
}

class ReceiveStateNotifier extends StateNotifier<ReceiveUiStateData> with WidgetsBindingObserver {
  bool _isListening = false;

  ReceiveStateNotifier() : super(const ReceiveUiStateData()) {
    _startListening();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No special handling needed for receive on lifecycle changes
  }

  void _startListening() {
    if (_isListening) return;
    _isListening = true;

    AudioReceiveFlutterApi.setUp(_ReceiveFlutterApiImpl(this));
  }

  void handleStreamStateChanged(String stateStr, ReceiveStats? stats) {
    debugPrint('[Receive] Native stream state change: $stateStr');
    final uiState = _parseState(stateStr);
    state = state.copyWith(
      state: uiState,
      stats: stats,
      error: null,
    );
  }

  void handleError(String code, String message) {
    debugPrint('[Receive] Native error: $code - $message');
    state = state.copyWith(
      state: ReceiveUiState.failed,
      error: '$code: $message',
    );
  }

  ReceiveUiState _parseState(String state) {
    switch (state) {
      case 'IDLE':
        return ReceiveUiState.idle;
      case 'RECEIVING':
        return ReceiveUiState.receiving;
      case 'STOPPED':
        return ReceiveUiState.stopped;
      case 'FAILED':
        return ReceiveUiState.failed;
      default:
        return ReceiveUiState.idle;
    }
  }

  @override
  void dispose() {
    AudioReceiveFlutterApi.setUp(null);
    WidgetsBinding.instance.removeObserver(this);
    _isListening = false;
    super.dispose();
  }
}

class _ReceiveFlutterApiImpl implements AudioReceiveFlutterApi {
  final ReceiveStateNotifier _notifier;

  _ReceiveFlutterApiImpl(this._notifier);

  @override
  void onStreamStateChanged(String state, ReceiveStats? stats) {
    _notifier.handleStreamStateChanged(state, stats);
  }
}

final receiveStateProvider = StateNotifierProvider<ReceiveStateNotifier, ReceiveUiStateData>((ref) {
  return ReceiveStateNotifier();
});