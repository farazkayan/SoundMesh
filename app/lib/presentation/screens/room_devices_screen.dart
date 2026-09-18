import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class RoomDevicesScreen extends StatelessWidget {
  const RoomDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StateBuilder(
      builder: (context, appState) {
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: SMSpacing.xl,
                vertical: SMSpacing.xl,
              ),
              child: _buildContent(context, appState),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ApplicationState appState) {
    final state = appState.state;

    switch (state) {
      case SMAppState.error:
        return Column(
          children: [
            SMEmptyState.error(
              title: 'Room Error',
              message: appState.message ?? 'Something went wrong.',
              icon: Icons.error_outline,
              onRetry: () => StateProvider.of(context).leaveRoom(),
            ),
            SizedBox(height: SMSpacing.xxl),
          ],
        );

      case SMAppState.preparing:
        return _preparingContent(context, appState);

      case SMAppState.ready:
      case SMAppState.playing:
      case SMAppState.paused:
        return _devicesContent(context, appState);

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _devicesContent(context, appState);
    }
  }

  Widget _devicesContent(BuildContext context, ApplicationState appState) {
    final sync = appState.sync;
    final status = sync?.syncState ?? SMSyncStatus.unknown;
    final bool isSynchronized = status == SMSyncStatus.synchronized;
    final bool isCalibrating = status == SMSyncStatus.calibrating ||
        status == SMSyncStatus.preparing ||
        status == SMSyncStatus.resynchronizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Devices header
        Text(
          'Devices',
          style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Connected devices in this room.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xl),
        // Device list (placeholder)
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Icon(
                Icons.devices,
                size: SMDimensions.emptyIconSize,
                color: SMColors.soundmeshBlue,
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                'No devices connected',
                style: SMTypography.heading
                    .copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Devices will appear here once they join the room.\n'
                'Each device shows its name, role, connection state, and sync status.',
                textAlign: TextAlign.center,
                style: SMTypography.body
                    .copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.lg),
              const Text(
                '[UI SCAFFOLDING — NO REAL DEVICE DATA]',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SMColors.warning,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        // Sync status card
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Icon(
                isSynchronized
                    ? Icons.sync
                    : (isCalibrating ? Icons.sync : Icons.sync_disabled),
                size: SMDimensions.emptyIconSize,
                color: isSynchronized
                    ? SMColors.success
                    : (isCalibrating ? SMColors.warning : SMColors.warning),
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                isSynchronized ? 'Synchronized' : 'Not Synchronized',
                style: SMTypography.heading
                    .copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                isSynchronized
                    ? 'Devices are calibrated and ready for synchronized session.'
                    : 'Devices have not been calibrated for synchronized session.\n'
                        'Run calibration to measure and compensate for latency differences.',
                textAlign: TextAlign.center,
                style: SMTypography.body
                    .copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.xl),
              if (isSynchronized && sync != null && sync.offsetMs != null)
                Text(
                  'Offset: ${sync.offsetMs!.toStringAsFixed(1)} ms · '
                  'Drift: ${sync.driftMsPerSecond?.toStringAsFixed(2) ?? "?"} ms/s',
                  style: SMTypography.caption
                      .copyWith(color: SMColors.secondaryText),
                ),
              SizedBox(height: SMSpacing.xl),
              SMButton(
                text: isSynchronized ? 'Re-calibrate' : 'Calibrate Devices',
                icon: isCalibrating ? Icons.sync : Icons.sync,
                variant: SMButtonVariant.primary,
                onPressed: isCalibrating
                    ? null
                    : () => StateProvider.of(context).prepare(),
                enabled: !isCalibrating,
              ),
              if (isCalibrating) ...[
                SizedBox(height: SMSpacing.md),
                SMLoadingIndicator(size: SMDimensions.loadingSize),
                SizedBox(height: SMSpacing.sm),
                Text(
                  'Calibrating…',
                  textAlign: TextAlign.center,
                  style: SMTypography.caption
                      .copyWith(color: SMColors.secondaryText),
                ),
              ],
              SizedBox(height: SMSpacing.lg),
              const Text(
                '[UI SCAFFOLDING — NO REAL CALIBRATION LOGIC]',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SMColors.warning,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xl),
        // Back to Room button
        SMButton(
          text: 'Back to Room',
          variant: SMButtonVariant.secondary,
          onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.roomDashboard),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _preparingContent(BuildContext context, ApplicationState appState) {
    return Column(
      children: [
        SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
        SizedBox(height: SMSpacing.lg),
        Text(
          appState.message ?? 'Preparing devices…',
          textAlign: TextAlign.center,
          style:
              SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Waiting for all devices to prepare for synchronized session.',
          textAlign: TextAlign.center,
          style:
              SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xl),
        SMButton(
          text: 'Back to Room',
          variant: SMButtonVariant.secondary,
          onPressed: () => StateProvider.of(context).leaveRoom(),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _stoppingContent(ApplicationState appState) {
    return Column(
      children: [
        SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
        SizedBox(height: SMSpacing.lg),
        Text(
          appState.message ?? 'Stopping…',
          textAlign: TextAlign.center,
          style:
              SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Wrapping up calibration and releasing devices.',
          textAlign: TextAlign.center,
          style:
              SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }
}
