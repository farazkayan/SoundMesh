import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';
import '../repositories/timing_info_repository.dart';
import '../synchronization/sync_state.dart';
import 'capture_provider.dart';
import 'sync_provider.dart';

/// Conservative startup scheduling margin (200ms).
/// This is NOT measured latency — Phase 12 presentation latency is unavailable
/// because clockDomainAligned=false.
/// It is an explicitly documented Phase 13 scheduling safety margin.
const int conservativeStartupMarginNs = 200_000_000;

/// Timeline scheduler that computes shared-timeline targets and drives native scheduling.
class _TimelineScheduler {
  _TimelineScheduler(this.ref, this.timingRepo, this.receivePlatform, this.outputPlatform);

  final Ref ref;
  final TimingInfoRepository timingRepo;
  final AudioReceivePlatform receivePlatform;
  final AudioOutputPlatform outputPlatform;

  int _currentGeneration = 0;

  void start() {
    // Trigger on sync state changes
    ref.listen<AsyncValue<SyncStatus>>(syncStatusProvider, (_, next) {
      if (next is AsyncData<SyncStatus>) {
        _onSyncStatusChanged(next.value);
      }
    });

    // Trigger on stream start
    ref.listen<CaptureUiStateData>(captureStateProvider, (_, next) {
      if (next.streamingMetadata != null && next.streamState == 'STREAMING') {
        _onStreamStart(next.streamingMetadata!);
      }
    });
  }

  void _onSyncStatusChanged(SyncStatus status) {
    if (status.generation == 0) return;
    if (status.generation != _currentGeneration) return;
    _scheduleNextFrame(status);
  }

  void _onStreamStart(StreamingMetadata metadata) {
    _currentGeneration = metadata.generation;
    // Get initial sync status and schedule
    final syncStatus = ref.read(syncStatusProvider).valueOrNull;
    if (syncStatus != null && syncStatus.generation == metadata.generation) {
      _scheduleNextFrame(syncStatus);
    }
  }

  Future<void> _scheduleNextFrame(SyncStatus syncStatus) async {
    // Get next frame info from native receive engine
    final nextFrameInfo = await receivePlatform.getNextFrameInfo();
    if (nextFrameInfo == null) {
      debugPrint('[Timeline] No next frame info available');
      return;
    }

    // Verify generation matches
    if (nextFrameInfo.generation != _currentGeneration) {
      debugPrint('[Timeline] Generation mismatch: nextFrame=${nextFrameInfo.generation} current=$_currentGeneration');
      return;
    }

    // Get stream metadata from capture state
    final captureState = ref.read(captureStateProvider);
    final metadata = captureState.streamingMetadata;
    if (metadata == null) {
      debugPrint('[Timeline] No stream metadata available');
      return;
    }

    // Get current participant monotonic time
    final nowNs = await timingRepo.getMonotonicTimeNanos();

    // Compute shared timeline time for the candidate frame
    // sharedTimelineNs = startedAtNanos + framePosition * 1e9 / sampleRate
    final framePos = nextFrameInfo.framePosition;
    final sharedTimelineNs = metadata.startedAtNanos +
        (framePos * 1_000_000_000 ~/ nextFrameInfo.sampleRate);

    // Compute target based on sync state
    int targetNs;
    switch (syncStatus.state) {
      case SyncState.unsynchronized:
        targetNs = math.max(0, nowNs + conservativeStartupMarginNs);
        break;
      case SyncState.synchronizing:
        if (syncStatus.offsetMs != null && syncStatus.validSampleCount > 0) {
          final offsetNs = (syncStatus.offsetMs! * 1_000_000).round();
          final uncertaintyNs = (syncStatus.uncertaintyMs! * 1_000_000).round();
          final rttNs = (syncStatus.rttMs! * 1_000_000).round();
          final marginNs = conservativeStartupMarginNs + rttNs + uncertaintyNs;
          targetNs = (sharedTimelineNs - offsetNs + marginNs).round();
        } else {
          targetNs = nowNs + conservativeStartupMarginNs;
        }
        break;
      case SyncState.synchronized:
        final offsetNs = (syncStatus.offsetMs! * 1_000_000).round();
        final rttMs = syncStatus.rttMs!.ceil();
        final marginNs = (math.max(rttMs, 60) * 2_000_000).toInt();
        targetNs = sharedTimelineNs - offsetNs + marginNs;
        break;
      case SyncState.degraded:
        final offsetNs = (syncStatus.offsetMs! * 1_000_000).round();
        final rttMs = syncStatus.rttMs!.ceil();
        final uncertaintyNs = (syncStatus.uncertaintyMs! * 1_000_000).round();
        final marginNs = (math.max(rttMs, 60) * 2_000_000 + uncertaintyNs).toInt();
        targetNs = sharedTimelineNs - offsetNs + marginNs;
        break;
    }

    // Ensure target is in the future
    if (targetNs <= nowNs + 10_000_000) { // 10ms safety
      // Target already missed or too close — skip
      return;
    }

    // Schedule the frame
    await outputPlatform.scheduleFrame(
      nextFrameInfo.framePosition,
      targetNs,
      nextFrameInfo.generation,
    );

    debugPrint(
      '[Timeline] Scheduled frame=${nextFrameInfo.framePosition} '
      'targetNs=$targetNs gen=${nextFrameInfo.generation} '
      'state=${syncStatus.state.wireValue}',
    );
  }

  void dispose() {
    // ref.listen subscriptions are automatically cleaned up when the provider is disposed
  }
}

final timelineSchedulerProvider = Provider<_TimelineScheduler>((ref) {
  final timingRepo = ref.watch(timingInfoRepositoryProvider);
  final receivePlatform = ref.watch(audioReceivePlatformProvider);
  final outputPlatform = ref.watch(audioOutputPlatformProvider);

  final scheduler = _TimelineScheduler(ref, timingRepo, receivePlatform, outputPlatform);
  // Start the scheduler - it will listen to sync and stream state changes
  scheduler.start();

  ref.onDispose(() {
    scheduler.dispose();
  });

  return scheduler;
});