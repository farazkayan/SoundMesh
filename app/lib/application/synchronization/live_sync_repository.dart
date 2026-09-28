import 'dart:async';
import 'package:soundmesh/application/protocol/protocol_message.dart';
import 'package:soundmesh/application/repositories/timing_info_repository.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'sync_state.dart';
import 'sample_history.dart';
import 'outlier_filter.dart';
import 'sync_repository.dart';

/// Per-participant synchronization state container
class _ParticipantSyncState {
  final SampleHistory sampleHistory = SampleHistory(maxSamples: 20);
  final SyncStateMachine stateMachine = SyncStateMachine();

  final StreamController<SyncStatus> statusController =
      StreamController<SyncStatus>.broadcast();

  Timer? calibrationTimer;
  int pendingExchangeT1 = 0;
  bool exchangeInProgress = false;
  bool disposed = false;

  final String participantId;
  final int pipelineGeneration;
  final String sessionId;
  final String localDeviceId;
  final TimingInfoRepository _timingRepo;
  final NetworkRepository _networkRepo;

  _ParticipantSyncState({
    required this.participantId,
    required this.pipelineGeneration,
    required this.sessionId,
    required this.localDeviceId,
    required this._timingRepo,
    required this._networkRepo,
  }) {
    stateMachine.reset(generation: pipelineGeneration);
    _emitStatus();
    _startCalibration();
  }

  SyncStatus get currentStatus {
    if (sampleHistory.getValidSampleCount(currentGeneration: pipelineGeneration) == 0) {
      return SyncStatus.unsynchronized(generation: pipelineGeneration);
    }
    final estimate = sampleHistory.getCurrentEstimate(currentGeneration: pipelineGeneration);
    final state = stateMachine.currentState;
    return SyncStatus.fromEstimate(
      estimate: estimate!,
      state: state,
      generation: pipelineGeneration,
      validSampleCount: sampleHistory.getValidSampleCount(currentGeneration: pipelineGeneration),
    );
  }

  Stream<SyncStatus> get statusStream => statusController.stream;

  Future<void> calibrate() async {
    await _performExchange();
  }

  Future<void> requestResync() async {
    sampleHistory.clear();
    stateMachine.reset(generation: pipelineGeneration);
    _emitStatus();
    await _performExchange();
  }

  void onTimeSyncResponse({
    required int t1,
    required int t2,
    required int t3,
    required int generation,
  }) async {
    if (generation != pipelineGeneration) return;
    if (!exchangeInProgress || t1 != pendingExchangeT1) return;

    exchangeInProgress = false;
    final t4 = await _timingRepo.getMonotonicTimeNanos();

    final validation = OutlierFilter.validate(
      t1: t1,
      t2: t2,
      t3: t3,
      t4: t4,
      generation: generation,
      currentGeneration: pipelineGeneration,
      recentSamples: sampleHistory.getValidSamples(
        currentGeneration: pipelineGeneration,
        nowNs: t4,
      ),
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
      sampleHistory.addSample(sample);
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
      sampleHistory.addSample(sample);
    }

    stateMachine.evaluate(
      validSampleCount: sampleHistory.getValidSampleCount(
        currentGeneration: pipelineGeneration,
        nowNs: t4,
      ),
      currentUncertaintyNs: sampleHistory.getCurrentEstimate(currentGeneration: pipelineGeneration)?.uncertaintyNs,
      hasUsableEstimate: sampleHistory.getValidSampleCount(
        currentGeneration: pipelineGeneration,
        nowNs: t4,
      ) > 0,
    );

    _emitStatus();
  }

  void onSessionGenerationChanged(int newGeneration) {
    if (newGeneration != pipelineGeneration) {
      dispose();
    }
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    calibrationTimer?.cancel();
    statusController.close();
  }

  void _startCalibration() {
    _performExchange();

    calibrationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!disposed) {
        _performExchange();
      }
    });
  }

  Future<void> _performExchange() async {
    if (exchangeInProgress || disposed) return;

    exchangeInProgress = true;
    pendingExchangeT1 = await _timingRepo.getMonotonicTimeNanos();

    final request = ProtocolMessage.timeSyncRequest(
      senderId: localDeviceId,
      sessionId: sessionId,
      t1: pendingExchangeT1,
      generation: pipelineGeneration,
    );

    try {
      await _networkRepo.sendProtocolMessage(request);
    } catch (e) {
      exchangeInProgress = false;
    }
  }

  void _emitStatus() {
    if (!statusController.isClosed) {
      statusController.add(currentStatus);
    }
  }
}

class LiveSyncRepository implements SyncRepository {
  final TimingInfoRepository _timingRepo;
  final NetworkRepository _networkRepo;
  final int _pipelineGeneration;
  final String _sessionId;
  final String _localDeviceId;

  final Map<String, _ParticipantSyncState> _participantStates = {};
  bool _disposed = false;

  LiveSyncRepository({
    required this._timingRepo,
    required this._networkRepo,
    required this._pipelineGeneration,
    required this._sessionId,
    required this._localDeviceId,
  });

  _ParticipantSyncState _getOrCreateState(String participantId) {
    return _participantStates.putIfAbsent(participantId, () => _ParticipantSyncState(
      participantId: participantId,
      pipelineGeneration: _pipelineGeneration,
      sessionId: _sessionId,
      localDeviceId: _localDeviceId,
      timingRepo: _timingRepo,
      networkRepo: _networkRepo,
    ));
  }

  void removeParticipant(String participantId) {
    _participantStates.remove(participantId)?.dispose();
  }

  /// Test helper: directly process a sync sample for a participant with known timestamps.
  /// Bypasses exchange tracking for testing purposes.
  Future<void> testProcessSyncSample({
    required String participantId,
    required int t1,
    required int t2,
    required int t3,
    required int t4,
    required int generation,
  }) async {
    final state = _getOrCreateState(participantId);
    if (generation != state.pipelineGeneration) return;

    final validation = OutlierFilter.validate(
      t1: t1,
      t2: t2,
      t3: t3,
      t4: t4,
      generation: generation,
      currentGeneration: state.pipelineGeneration,
      recentSamples: state.sampleHistory.getValidSamples(currentGeneration: state.pipelineGeneration),
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
      state.sampleHistory.addSample(sample);
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
      state.sampleHistory.addSample(sample);
    }

    state.stateMachine.evaluate(
      validSampleCount: state.sampleHistory.getValidSampleCount(currentGeneration: state.pipelineGeneration),
      currentUncertaintyNs: state.sampleHistory.getCurrentEstimate(currentGeneration: state.pipelineGeneration)?.uncertaintyNs,
      hasUsableEstimate: state.sampleHistory.getValidSampleCount(currentGeneration: state.pipelineGeneration) > 0,
    );

    state._emitStatus();
  }

  @override
  Stream<SyncStatus> statusStream({String? participantId}) {
    if (participantId != null) {
      final state = _participantStates[participantId];
      return state?.statusStream ?? Stream.value(SyncStatus.unsynchronized(generation: _pipelineGeneration));
    }
    // Return a merged stream of all participants (for backward compatibility)
    // For now, return first available or empty
    if (_participantStates.isEmpty) {
      return Stream.value(SyncStatus.unsynchronized(generation: _pipelineGeneration));
    }
    return _participantStates.values.first.statusStream;
  }

  @override
  SyncStatus getCurrentStatus({required String participantId}) {
    final state = _participantStates[participantId];
    if (state == null) {
      return SyncStatus.unsynchronized(generation: _pipelineGeneration);
    }
    return state.currentStatus;
  }

  @override
  Future<void> calibrate({required String participantId}) async {
    final state = _getOrCreateState(participantId);
    await state.calibrate();
  }

  @override
  Future<void> requestResync({required String participantId}) async {
    final state = _getOrCreateState(participantId);
    await state.requestResync();
  }

  @override
  Future<void> onTimeSyncResponse({
    required String participantId,
    required int t1,
    required int t2,
    required int t3,
    required int generation,
  }) async {
    final state = _participantStates[participantId];
    if (state == null) return;

    if (generation != state.pipelineGeneration) return;
    if (!state.exchangeInProgress || t1 != state.pendingExchangeT1) return;

    state.exchangeInProgress = false;
    final t4 = await _timingRepo.getMonotonicTimeNanos();

    final validation = OutlierFilter.validate(
      t1: t1,
      t2: t2,
      t3: t3,
      t4: t4,
      generation: generation,
      currentGeneration: state.pipelineGeneration,
      recentSamples: state.sampleHistory.getValidSamples(
        currentGeneration: state.pipelineGeneration,
        nowNs: t4,
      ),
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
      state.sampleHistory.addSample(sample);
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
      state.sampleHistory.addSample(sample);
    }

    state.stateMachine.evaluate(
      validSampleCount: state.sampleHistory.getValidSampleCount(
        currentGeneration: state.pipelineGeneration,
        nowNs: t4,
      ),
      currentUncertaintyNs: state.sampleHistory.getCurrentEstimate(currentGeneration: state.pipelineGeneration)?.uncertaintyNs,
      hasUsableEstimate: state.sampleHistory.getValidSampleCount(
        currentGeneration: state.pipelineGeneration,
        nowNs: t4,
      ) > 0,
    );

    state._emitStatus();
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
    for (final state in _participantStates.values) {
      state.dispose();
    }
    _participantStates.clear();
  }
}