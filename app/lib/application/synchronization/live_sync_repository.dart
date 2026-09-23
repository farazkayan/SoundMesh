import 'dart:async';
import 'package:soundmesh/application/protocol/protocol_message.dart';
import 'package:soundmesh/application/repositories/timing_info_repository.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'sync_state.dart';
import 'sample_history.dart';
import 'outlier_filter.dart';
import 'sync_repository.dart';

class LiveSyncRepository implements SyncRepository {
  final TimingInfoRepository _timingRepo;
  final NetworkRepository _networkRepo;
  final int _pipelineGeneration;
  final String _sessionId;
  final String _localDeviceId;

  final SampleHistory _sampleHistory = SampleHistory(maxSamples: 20);
  final SyncStateMachine _stateMachine = SyncStateMachine();

  final StreamController<SyncStatus> _statusController = StreamController<SyncStatus>.broadcast();
  Timer? _calibrationTimer;
  Timer? _exchangeTimer;
  int _pendingExchangeT1 = 0;
  bool _exchangeInProgress = false;
  bool _disposed = false;

  LiveSyncRepository({
    required this._timingRepo,
    required this._networkRepo,
    required this._pipelineGeneration,
    required this._sessionId,
    required this._localDeviceId,
  }) {
    _stateMachine.reset(generation: _pipelineGeneration);
    _startCalibration();
  }

  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;

  @override
  SyncStatus get currentStatus {
    if (_sampleHistory.getValidSampleCount(currentGeneration: _pipelineGeneration) == 0) {
      return SyncStatus.unsynchronized(generation: _pipelineGeneration);
    }
    final estimate = _sampleHistory.getCurrentEstimate(currentGeneration: _pipelineGeneration);
    final state = _stateMachine.currentState;
    return SyncStatus.fromEstimate(
      estimate: estimate!,
      state: state,
      generation: _pipelineGeneration,
      validSampleCount: _sampleHistory.getValidSampleCount(currentGeneration: _pipelineGeneration),
    );
  }

  @override
  Future<void> calibrate() async {
    await _performExchange();
  }

  @override
  Future<void> requestResync() async {
    _sampleHistory.clear();
    _stateMachine.reset(generation: _pipelineGeneration);
    _emitStatus();
    await _performExchange();
  }

  @override
  Future<void> onTimeSyncResponse({
    required int t1,
    required int t2,
    required int t3,
    required int generation,
  }) async {
    if (generation != _pipelineGeneration) return;
    if (!_exchangeInProgress || t1 != _pendingExchangeT1) return;

    _exchangeInProgress = false;
    final t4 = await _timingRepo.getMonotonicTimeNanos();

    final validation = OutlierFilter.validate(
      t1: t1,
      t2: t2,
      t3: t3,
      t4: t4,
      generation: generation,
      currentGeneration: _pipelineGeneration,
      recentSamples: _sampleHistory.getValidSamples(currentGeneration: _pipelineGeneration),
    );

    if (validation.valid) {
      final sample = SyncSample.fromExchange(
        t1: t1,
        t2: t2,
        t3: t3,
        t4: t4,
        generation: generation,
        receivedAtNs: t4,
        valid: true,
      );
      _sampleHistory.addSample(sample);
    } else {
      final sample = SyncSample.fromExchange(
        t1: t1,
        t2: t2,
        t3: t3,
        t4: t4,
        generation: generation,
        receivedAtNs: t4,
        valid: false,
        rejectionReason: validation.rejectionReason,
      );
      _sampleHistory.addSample(sample);
    }

    _stateMachine.evaluate(
      validSampleCount: _sampleHistory.getValidSampleCount(currentGeneration: _pipelineGeneration),
      currentUncertaintyNs: _sampleHistory.getCurrentEstimate(currentGeneration: _pipelineGeneration)?.uncertaintyNs,
      hasUsableEstimate: _sampleHistory.getValidSampleCount(currentGeneration: _pipelineGeneration) > 0,
    );

    _emitStatus();
  }

  @override
  void onSessionGenerationChanged(int newGeneration) {
    if (newGeneration != _pipelineGeneration) {
      dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _calibrationTimer?.cancel();
    _exchangeTimer?.cancel();
    _statusController.close();
  }

  void _startCalibration() {
    _performExchange();

    _calibrationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_disposed) {
        _performExchange();
      }
    });
  }

  Future<void> _performExchange() async {
    if (_exchangeInProgress || _disposed) return;

    _exchangeInProgress = true;
    _pendingExchangeT1 = await _timingRepo.getMonotonicTimeNanos();

    final request = ProtocolMessage.timeSyncRequest(
      senderId: _localDeviceId,
      sessionId: _sessionId,
      t1: _pendingExchangeT1,
      generation: _pipelineGeneration,
    );

    try {
      await _networkRepo.sendProtocolMessage(request);
    } catch (e) {
      _exchangeInProgress = false;
    }
  }

  void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(currentStatus);
    }
  }
}