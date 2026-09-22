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
  final int peakAmplitude;
  final bool isSilent;

  const ReceiveUiStateData({
    this.state = ReceiveUiState.idle,
    this.stats,
    this.error,
    this.peakAmplitude = 0,
    this.isSilent = true,
  });

  ReceiveUiStateData copyWith({
    ReceiveUiState? state,
    ReceiveStats? stats,
    String? error,
    int? peakAmplitude,
    bool? isSilent,
  }) {
    return ReceiveUiStateData(
      state: state ?? this.state,
      stats: stats ?? this.stats,
      error: error ?? this.error,
      peakAmplitude: peakAmplitude ?? this.peakAmplitude,
      isSilent: isSilent ?? this.isSilent,
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
      // Reset amplitude when stream state changes to non-receiving
      peakAmplitude: (uiState == ReceiveUiState.receiving) ? (stats?.peakAmplitude ?? 0) : 0,
      isSilent: (uiState == ReceiveUiState.receiving) ? (stats?.isSilent ?? true) : true,
    );
  }

  void handleAudioLevelUpdate(int peakAmplitude, bool isSilent) {
    // Only update if we're in receiving state; otherwise ignore (meter should be zero)
    if (state.state == ReceiveUiState.receiving) {
      state = state.copyWith(
        peakAmplitude: peakAmplitude,
        isSilent: isSilent,
      );
    }
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
      case 'STREAMING':
      case 'RECOVERING':
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

  @override
  void onAudioLevelUpdate(int peakAmplitude, bool isSilent) {
    _notifier.handleAudioLevelUpdate(peakAmplitude, isSilent);
  }
}

final receiveStateProvider = StateNotifierProvider<ReceiveStateNotifier, ReceiveUiStateData>((ref) {
  return ReceiveStateNotifier();
});