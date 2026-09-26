import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';
import '../repositories/network_repository.dart';
import '../repositories/timing_info_repository.dart';
import '../synchronization/live_sync_repository.dart';
import '../synchronization/sync_repository.dart';
import '../synchronization/sync_state.dart';

final syncRepositoryProvider = StateProvider<SyncRepository?>((ref) => null);

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final repository = ref.watch(syncRepositoryProvider);
  final networkRepo = ref.watch(networkRepositoryProvider);
  
  if (repository == null) {
    // Emit initial unsynchronized status instead of empty stream (which never emits)
    // This prevents UI from staying stuck on "Loading..." when no sync session is active
    return Stream.value(SyncStatus.unsynchronized(generation: 0));
  }
  
  // For backward compatibility, use the first joined participant's status
  // (for participant-side, there's only one; for host with multiple participants,
  // this shows the first participant's status)
  final participantIds = networkRepo.joinedParticipantIds;
  final primaryParticipantId = participantIds.isNotEmpty ? participantIds.first : null;
  
  // Combine initial status with subsequent updates
  final initialStatus = primaryParticipantId != null 
      ? repository.getCurrentStatus(participantId: primaryParticipantId)
      : SyncStatus.unsynchronized(generation: 0);
  return Stream.value(initialStatus).asyncExpand((_) => repository.statusStream(participantId: primaryParticipantId));
});

class _SyncRepositoryLifecycle {
  _SyncRepositoryLifecycle(this.ref, this.networkRepo, this.timingRepo, this.pipelinePlatform);

  final Ref ref;
  final NetworkRepository networkRepo;
  final TimingInfoRepository timingRepo;
  final PipelinePlatform pipelinePlatform;

  LiveSyncRepository? _currentRepo;
  StreamSubscription<void>? _generationSub;
  StreamSubscription<SyncStatus>? _syncStatusSub;
  int _currentGeneration = -1;

  void start() {
    _generationSub = _watchGeneration();
    // Register PipelineFlutterApi handler for TIME_SYNC_RESPONSE and pipeline state changes from native
    PipelineFlutterApi.setUp(_PipelineFlutterApi(
      _onTimeSyncResponseFromNative,
      _onPipelineStateChangedFromNative,
    ));
  }

  void _onTimeSyncResponseFromNative(TimeSyncResponse response) {
    debugPrint(
      '[SyncProvider] _onTimeSyncResponseFromNative CALLED: '
      'gen=${response.generation} senderId=${response.senderId}',
    );
    if (_currentRepo == null) {
      debugPrint('[SyncProvider] DROPPED TIME_SYNC_RESPONSE: _currentRepo is NULL');
      return;
    }
    if (response.generation != _currentGeneration) {
      debugPrint(
        '[SyncProvider] DROPPED TIME_SYNC_RESPONSE: '
        'generation mismatch response=${response.generation} '
        'current=$_currentGeneration',
      );
      return;
    }
    if (response.senderId.isEmpty) {
      debugPrint('[SyncProvider] DROPPED TIME_SYNC_RESPONSE: senderId is empty');
      return;
    }
    debugPrint(
      '[SyncProvider] Forwarding TIME_SYNC_RESPONSE to LiveSyncRepository for participant ${response.senderId}',
    );
    _currentRepo!.onTimeSyncResponse(
      participantId: response.senderId,
      t1: response.t1,
      t2: response.t2,
      t3: response.t3,
      generation: response.generation,
    );
  }

  void _onPipelineStateChangedFromNative(String state, int generation) {
    // Native signals stream generation adoption via onPipelineStateChanged
    // This allows immediate LiveSyncRepository creation instead of waiting for 500ms poll
    if ((state == 'STREAM_INFO' || state == 'STREAM_START') && generation > 0) {
      debugPrint('[SyncProvider] Native signaled pipeline state: $state gen=$generation');
      if (generation != _currentGeneration) {
        _currentGeneration = generation;
        _onGenerationChanged(generation);
      }
    }
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
    // Cancel previous sync status subscription
    _syncStatusSub?.cancel();
    _syncStatusSub = null;

    if (generation == 0) {
      _disposeRepo();
      // Propagate UNSYNCHRONIZED for generation 0
      pipelinePlatform.updateSyncState('UNSYNCHRONIZED', 0, 0.0, null);
      debugPrint('[SyncProvider] Propagated sync state to native: UNSYNCHRONIZED (gen=0)');
      return;
    }

    final sessionId = networkRepo.sessionId;
    if (sessionId == null) {
      _disposeRepo();
      return;
    }

    final localDeviceId = networkRepo.participantId;

    _currentRepo = LiveSyncRepository(
      timingRepo: timingRepo,
      networkRepo: networkRepo,
      pipelineGeneration: generation,
      sessionId: sessionId,
      localDeviceId: localDeviceId,
    );

    ref.read(syncRepositoryProvider.notifier).state = _currentRepo!;

    // Subscribe to repo's status stream DIRECTLY for reliable propagation
    // This avoids StreamProvider stream-switching issues
    // For host with multiple participants, we listen to all and propagate each
    _syncStatusSub = _currentRepo!.statusStream().listen((status) {
      String nativeState;
      switch (status.state) {
        case SyncState.synchronized:
          nativeState = 'SYNCHRONIZED';
          break;
        case SyncState.degraded:
          nativeState = 'DEGRADED';
          break;
        case SyncState.synchronizing:
          nativeState = 'SYNCHRONIZING';
          break;
        case SyncState.unsynchronized:
          nativeState = 'UNSYNCHRONIZED';
          break;
      }
      pipelinePlatform.updateSyncState(
        nativeState,
        status.generation,
        status.offsetMs ?? 0.0,
        status.driftMsPerSecond,
      );
      debugPrint('[SyncProvider] Propagated sync state to native: $nativeState (gen=${status.generation})');
    });

    // Also emit initial status immediately for all participants
    for (final participantId in networkRepo.joinedParticipantIds) {
      final initialStatus = _currentRepo!.getCurrentStatus(participantId: participantId);
      String nativeState;
      switch (initialStatus.state) {
        case SyncState.synchronized:
          nativeState = 'SYNCHRONIZED';
          break;
        case SyncState.degraded:
          nativeState = 'DEGRADED';
          break;
        case SyncState.synchronizing:
          nativeState = 'SYNCHRONIZING';
          break;
        case SyncState.unsynchronized:
          nativeState = 'UNSYNCHRONIZED';
          break;
      }
      pipelinePlatform.updateSyncState(
        nativeState,
        initialStatus.generation,
        initialStatus.offsetMs ?? 0.0,
        initialStatus.driftMsPerSecond,
      );
      debugPrint('[SyncProvider] Propagated sync state to native: $nativeState (gen=${initialStatus.generation})');
    }
  }

  void _disposeRepo() {
    _syncStatusSub?.cancel();
    _syncStatusSub = null;
    _currentRepo?.dispose();
    _currentRepo = null;
    // Don't try to update provider state during disposal as container may be disposed
    // The provider will be reset when a new lifecycle is created
  }

  void dispose() {
    _generationSub?.cancel();
    _disposeRepo();
    PipelineFlutterApi.setUp(null);
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

final audioReceivePlatformProvider = Provider<AudioReceivePlatform>((ref) {
  return AudioReceivePlatform();
});

final audioOutputPlatformProvider = Provider<AudioOutputPlatform>((ref) {
  return AudioOutputPlatform();
});

class _PipelineFlutterApi implements PipelineFlutterApi {
  final void Function(TimeSyncResponse) _onTimeSyncResponse;
  final void Function(String state, int generation) _onPipelineStateChanged;

  _PipelineFlutterApi(this._onTimeSyncResponse, this._onPipelineStateChanged);

  @override
  void onPipelineStateChanged(String state, int generation) {
    _onPipelineStateChanged(state, generation);
  }

  @override
  void onPipelineError(PipelineError error) {
    // Not used for sync
  }

  @override
  void onTimeSyncResponse(TimeSyncResponse response) {
    debugPrint(
      '[PipelineFlutterApi] onTimeSyncResponse RECEIVED: '
      'gen=${response.generation} session=${response.sessionId}',
    );
    _onTimeSyncResponse(response);
  }

  @override
  void onSyncStateChanged(String state, int generation) {
    // Not used for sync
  }
}