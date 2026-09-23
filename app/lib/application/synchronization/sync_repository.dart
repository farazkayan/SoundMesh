import 'sync_state.dart';

abstract class SyncRepository {
  Stream<SyncStatus> get statusStream;

  SyncStatus get currentStatus;

  Future<void> calibrate();

  Future<void> requestResync();

  void onTimeSyncResponse({
    required int t1,
    required int t2,
    required int t3,
    required int generation,
  });

  void onSessionGenerationChanged(int newGeneration);

  void dispose();
}