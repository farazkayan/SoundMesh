import 'sync_state.dart';

abstract class SyncRepository {
  /// Stream of sync status for a specific participant, or all participants if participantId is null
  Stream<SyncStatus> statusStream({String? participantId});

  /// Get current sync status for a specific participant
  SyncStatus getCurrentStatus({required String participantId});

  /// Start calibration for a specific participant
  Future<void> calibrate({required String participantId});

  /// Request resync for a specific participant
  Future<void> requestResync({required String participantId});

  /// Handle TIME_SYNC_RESPONSE from a specific participant
  void onTimeSyncResponse({
    required String participantId,
    required int t1,
    required int t2,
    required int t3,
    required int generation,
  });

  /// Handle session generation change
  void onSessionGenerationChanged(int newGeneration);

  /// Dispose all resources
  void dispose();
}