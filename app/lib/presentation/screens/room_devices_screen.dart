import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';

class RoomDevicesScreen extends ConsumerWidget {
  const RoomDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);
    final participantJoined = lifecycleState.participantJoined;
    final isHost = appState.isHost == true;
    final deviceCount = 1 + (participantJoined ? 1 : 0);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.xl,
          ),
          child: _buildContent(context, appState, lifecycleState, deviceCount, participantJoined, isHost),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ApplicationState appState, RoomLifecycleStateData lifecycleState, int deviceCount, bool participantJoined, bool isHost) {
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
        return _devicesContent(context, appState, lifecycleState, deviceCount, participantJoined, isHost);

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _devicesContent(context, appState, lifecycleState, deviceCount, participantJoined, isHost);
    }
  }

  Widget _devicesContent(BuildContext context, ApplicationState appState, RoomLifecycleStateData lifecycleState, int deviceCount, bool participantJoined, bool isHost) {
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
        // Device count card
        _buildDeviceCountCard(deviceCount, participantJoined, isHost),
        SizedBox(height: SMSpacing.lg),
        // Device list (names only)
        _buildDeviceListCard(participantJoined, isHost),
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

  Widget _buildDeviceCountCard(int deviceCount, bool participantJoined, bool isHost) {
    return SMCard(
      elevated: true,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SMColors.surfaceContainer,
              borderRadius: BorderRadius.circular(SMRadius.medium),
            ),
            child: Icon(
              Icons.devices,
              size: 20,
              color: SMColors.soundmeshBlue,
            ),
          ),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Devices',
                  style: SMTypography.body.copyWith(color: SMColors.primaryText),
                ),
                SizedBox(height: SMSpacing.xs),
                // Count on first line, badge/status on second line to avoid overflow
                Text(
                  '$deviceCount device${deviceCount == 1 ? '' : 's'} connected',
                  style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                ),
                if (participantJoined || isHost) ...[
                  SizedBox(height: SMSpacing.xs),
                  if (participantJoined)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: SMColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(SMRadius.small),
                      ),
                      child: Text(
                        'PARTICIPANT JOINED',
                        style: SMTypography.metadata.copyWith(
                          color: SMColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (isHost)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: SMColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(SMRadius.small),
                      ),
                      child: Text(
                        'WAITING',
                        style: SMTypography.metadata.copyWith(
                          color: SMColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListCard(bool participantJoined, bool isHost) {
    return SMCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Devices',
            style: SMTypography.label.copyWith(color: SMColors.secondaryText),
          ),
          SizedBox(height: SMSpacing.md),
          _DeviceRow(
            name: isHost ? 'This Device (Host)' : 'This Device (Participant)',
            role: isHost ? 'HOST' : 'PARTICIPANT',
            roleColor: isHost ? SMColors.soundmeshBlue : SMColors.secondaryText,
            isCurrent: true,
          ),
          if (participantJoined) ...[
            Divider(color: SMColors.divider, height: SMSpacing.lg),
            _DeviceRow(
              name: 'Participant',
              role: 'PARTICIPANT',
              roleColor: SMColors.secondaryText,
              isCurrent: false,
            ),
          ] else if (isHost) ...[
            Divider(color: SMColors.divider, height: SMSpacing.lg),
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  size: 16,
                  color: SMColors.warning,
                ),
                SizedBox(width: SMSpacing.sm),
                Text(
                  'Waiting for participant to join…',
                  style: SMTypography.body.copyWith(color: SMColors.warning),
                ),
              ],
            ),
          ],
          SizedBox(height: SMSpacing.sm),
          Text(
            '[NAMES ONLY — FULL PER-DEVICE STATE IS PHASE 9]',
            style: SMTypography.metadata.copyWith(color: SMColors.warning),
          ),
        ],
      ),
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

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.name,
    required this.role,
    required this.roleColor,
    required this.isCurrent,
  });

  final String name;
  final String role;
  final Color roleColor;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isCurrent ? Icons.phone_android : Icons.phone_android_outlined,
          size: 20,
          color: isCurrent ? SMColors.soundmeshBlue : SMColors.secondaryText,
        ),
        SizedBox(width: SMSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: SMTypography.body.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 1),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(SMRadius.small),
                ),
                child: Text(
                  role,
                  style: SMTypography.metadata.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCurrent)
          Container(
            padding: EdgeInsets.symmetric(horizontal: SMSpacing.xs, vertical: 1),
            decoration: BoxDecoration(
              color: SMColors.soundmeshBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(SMRadius.small),
            ),
            child: Text(
              'YOU',
              style: SMTypography.metadata.copyWith(
                color: SMColors.soundmeshBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
