import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';
import '../protocol/protocol_message.dart';
import '../protocol/protocol_constants.dart';
import '../repositories/network_repository.dart';
import '../repositories/timing_info_repository.dart';
import '../synchronization/live_sync_repository.dart';
import '../synchronization/sync_repository.dart';
import '../synchronization/sync_state.dart';

final syncRepositoryProvider = StateProvider<SyncRepository?>((ref) => null);

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final repository = ref.watch(syncRepositoryProvider);
  if (repository == null) {
    // Emit initial unsynchronized status instead of empty stream (which never emits)
    // This prevents UI from staying stuck on "Loading..." when no sync session is active
    return Stream.value(SyncStatus.unsynchronized(generation: 0));
  }
  // Combine initial status with subsequent updates
  return Stream.value(repository.currentStatus).asyncExpand((_) => repository.statusStream);
});

class _SyncRepositoryLifecycle {
  _SyncRepositoryLifecycle(this.ref, this.networkRepo, this.timingRepo, this.pipelinePlatform);

  final Ref ref;
  final NetworkRepository networkRepo;
  final TimingInfoRepository timingRepo;
  final PipelinePlatform pipelinePlatform;

  LiveSyncRepository? _currentRepo;
  StreamSubscription<ProtocolMessage>? _protocolSub;
  StreamSubscription<void>? _generationSub;
  int _currentGeneration = -1;

  void start() {
    _generationSub = _watchGeneration();
  }

  StreamSubscription<void> _watchGeneration() {
    return Stream.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final generation = await pipelinePlatform.getPipelineGeneration();
        if (generation != _currentGeneration) {
          _currentGeneration = generation;
          _onGenerationChanged(generation);
        }
      } catch (e) {
        debugPrint('[SyncProvider] Failed to get pipeline generation: $e');
      }
    }).asyncMap((_) => _currentGeneration).listen((_) {});
  }

  void _onGenerationChanged(int generation) {
    if (generation == 0) {
      _disposeRepo();
      return;
    }

    final sessionId = networkRepo.sessionId;
    if (sessionId == null) {
      _disposeRepo();
      return;
    }

    final localDeviceId = networkRepo.participantId;

    // Cancel any existing protocol subscription BEFORE creating new repo
    // to avoid missing responses during the swap
    _protocolSub?.cancel();

    _currentRepo = LiveSyncRepository(
      timingRepo: timingRepo,
      networkRepo: networkRepo,
      pipelineGeneration: generation,
      sessionId: sessionId,
      localDeviceId: localDeviceId,
    );

    ref.read(syncRepositoryProvider.notifier).state = _currentRepo!;

    // Subscribe to TIME_SYNC_RESPONSE messages AFTER repo is created and registered
    // This ensures no responses are missed during the initial exchange
    _protocolSub = networkRepo.protocolMessageStream.listen((message) {
      final messageType = ProtocolMessageTypeX.fromWireValue(message.messageType);
      if (messageType == ProtocolMessageType.timeSyncResponse) {
        final payload = message.payload;
        if (payload != null) {
          final t1 = payload['t1'] as int?;
          final t2 = payload['t2'] as int?;
          final t3 = payload['t3'] as int?;
          if (t1 != null && t2 != null && t3 != null) {
            _currentRepo?.onTimeSyncResponse(
              t1: t1,
              t2: t2,
              t3: t3,
              generation: message.generation,
            );
          }
        }
      }
    });
  }

  void _disposeRepo() {
    _protocolSub?.cancel();
    _protocolSub = null;
    _currentRepo?.dispose();
    _currentRepo = null;
    // Don't try to update provider state during disposal as container may be disposed
    // The provider will be reset when a new lifecycle is created
  }

  void dispose() {
    _generationSub?.cancel();
    _disposeRepo();
  }
}

final syncLifecycleProvider = Provider<_SyncRepositoryLifecycle>((ref) {
  final networkRepo = ref.watch(networkRepositoryProvider);
  final timingRepo = ref.watch(timingInfoRepositoryProvider);
  final pipelinePlatform = ref.watch(pipelinePlatformProvider);

  final lifecycle = _SyncRepositoryLifecycle(ref, networkRepo, timingRepo, pipelinePlatform);
  lifecycle.start();

  ref.onDispose(() {
    lifecycle.dispose();
  });

  return lifecycle;
});

final pipelinePlatformProvider = Provider<PipelinePlatform>((ref) {
  return PipelinePlatform();
});