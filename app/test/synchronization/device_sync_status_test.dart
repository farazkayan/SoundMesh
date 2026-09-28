import 'package:flutter_test/flutter_test.dart';

import 'package:soundmesh/application/synchronization/sync_state.dart';

void main() {
  group('DeviceAPI sync status contract (device-api.md §13)', () {
    test('SyncStatus exposed to device API includes driftMsPerSecond', () {
      // This test verifies the shape expected by device-api.md for sync status
      // reported to other devices in the mesh.
      final status = SyncStatus(
        state: SyncState.synchronized,
        offsetMs: 2.8,
        rttMs: 6.1,
        uncertaintyMs: 1.5,
        driftMsPerSecond: 0.18,
        confidence: null, // Per contract: no defensible confidence model
        lastMeasurementNs: 5_555_555_555_555,
        generation: 4,
        validSampleCount: 11,
      );

      final json = status.toJson();

      // device-api.md §13: "driftMsPerSecond: number (ms/s) — effective sync drift rate"
      expect(json['driftMsPerSecond'], equals(0.18));
      // confidence remains null per contract
      expect(json['confidence'], isNull);
    });

    test('Drift state machine states match documented states', () {
      // device-api.md references SyncState values
      for (final state in [
        'UNSYNCHRONIZED',
        'SYNCHRONIZING',
        'SYNCHRONIZED',
        'DEGRADED',
      ]) {
        final syncState = SyncStateX.fromWireValue(state);
        expect(syncState.wireValue, equals(state));
      }
    });

    test('SyncStatus with null driftMsPerSecond is valid for device API', () {
      // When drift cannot be measured (insufficient samples), driftMsPerSecond is null
      final status = SyncStatus(
        state: SyncState.synchronizing,
        offsetMs: 1.2,
        rttMs: 4.0,
        uncertaintyMs: 2.0,
        driftMsPerSecond: null,
        confidence: null,
        lastMeasurementNs: 1_111_111_111_111,
        generation: 2,
        validSampleCount: 5,
      );

      final json = status.toJson();
      expect(json['driftMsPerSecond'], isNull);
      expect(json['state'], equals('SYNCHRONIZING'));
    });
  });
}