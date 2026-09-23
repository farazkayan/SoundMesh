import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/application/providers/room_lifecycle_provider.dart';
import 'package:soundmesh/application/repositories/network_repository.dart';
import 'package:soundmesh/presentation/screens/debug_screen.dart';

class RoomDevicesScreen extends ConsumerWidget {
  const RoomDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final lifecycleState = ref.watch(roomLifecycleProvider);
    final connectionState = ref.watch(networkRepositoryProvider.select((r) => r.currentState));
    final participantJoined = lifecycleState.participantJoined;
    final isHost = appState.isHost == true;
    final deviceCount = 1 + (participantJoined ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Devices',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        backgroundColor: SMColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: SMColors.primaryText),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugScreen()),
              );
            },
            tooltip: 'Debug / Diagnostics',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.xl,
          ),
          child: _buildContent(context, appState, lifecycleState, connectionState, deviceCount, participantJoined, isHost),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ApplicationState appState, RoomLifecycleStateData lifecycleState, NetworkConnectionState connectionState, int deviceCount, bool participantJoined, bool isHost) {
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
        return _devicesContent(context, appState, lifecycleState, connectionState, deviceCount, participantJoined, isHost);

      case SMAppState.stopping:
        return _stoppingContent(appState);

      case SMAppState.roomReady:
      case SMAppState.idle:
      case SMAppState.creatingRoom:
      case SMAppState.joiningRoom:
        return _devicesContent(context, appState, lifecycleState, connectionState, deviceCount, participantJoined, isHost);
    }
  }

  Widget _devicesContent(BuildContext context, ApplicationState appState, RoomLifecycleStateData lifecycleState, NetworkConnectionState connectionState, int deviceCount, bool participantJoined, bool isHost) {
    final sync = appState.sync;
    final status = sync?.syncState ?? SMSyncStatus.unknown;
    final bool isSynchronized = status == SMSyncStatus.synchronized;
    final bool isCalibrating = status == SMSyncStatus.calibrating ||
        status == SMSyncStatus.preparing ||
        status == SMSyncStatus.resynchronizing;

    // Room-level connection status (not per-device)
    final String roomConnectionLabel;
    final Color roomConnectionColor;
    final IconData roomConnectionIcon;
    switch (connectionState) {
      case NetworkConnectionState.ready:
        roomConnectionLabel = 'Connected';
        roomConnectionColor = SMColors.success;
        roomConnectionIcon = Icons.wifi;
        break;
      case NetworkConnectionState.handshaking:
        roomConnectionLabel = 'Handshaking…';
        roomConnectionColor = SMColors.warning;
        roomConnectionIcon = Icons.sync;
        break;
      case NetworkConnectionState.listening:
        roomConnectionLabel = isHost ? 'Listening for participant…' : 'Connecting…';
        roomConnectionColor = SMColors.warning;
        roomConnectionIcon = isHost ? Icons.wifi_tethering : Icons.wifi;
        break;
      case NetworkConnectionState.connecting:
        roomConnectionLabel = 'Connecting…';
        roomConnectionColor = SMColors.warning;
        roomConnectionIcon = Icons.wifi;
        break;
      case NetworkConnectionState.reconnecting:
        roomConnectionLabel = 'Reconnecting…';
        roomConnectionColor = SMColors.warning;
        roomConnectionIcon = Icons.sync;
        break;
      case NetworkConnectionState.failed:
        roomConnectionLabel = 'Connection failed';
        roomConnectionColor = SMColors.error;
        roomConnectionIcon = Icons.wifi_off;
        break;
      case NetworkConnectionState.disconnected:
      default:
        roomConnectionLabel = 'Disconnected';
        roomConnectionColor = SMColors.error;
        roomConnectionIcon = Icons.wifi_off;
        break;
    }

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
        // Device list (names + role only — no per-device state available)
        _buildDeviceListCard(participantJoined, isHost),
        SizedBox(height: SMSpacing.xl),
        // Room-level connection status card
        SMCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Room Connection',
                style: SMTypography.label.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.lg),
              Row(
                children: [
                  Icon(
                    roomConnectionIcon,
                    size: SMDimensions.iconSize,
                    color: roomConnectionColor,
                  ),
                  SizedBox(width: SMSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomConnectionLabel,
                          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                        ),
                        SizedBox(height: SMSpacing.xs),
                        Text(
                          'Room-level network state — not per-device',
                          style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.lg),
        // Room-level sync status card
        SMCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Room Sync Status',
                style: SMTypography.label.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.lg),
              Row(
                children: [
                  Icon(
                    isSynchronized
                        ? Icons.sync
                        : (isCalibrating ? Icons.sync : Icons.sync_disabled),
                    size: SMDimensions.iconSize,
                    color: isSynchronized
                        ? SMColors.success
                        : (isCalibrating ? SMColors.warning : SMColors.warning),
                  ),
                  SizedBox(width: SMSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSynchronized ? 'Synchronized' : 'Not Synchronized',
                          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                        ),
                        SizedBox(height: SMSpacing.xs),
                        Text(
                          isSynchronized
                              ? 'Devices are calibrated and ready for synchronized session.'
                              : 'Devices have not been calibrated for synchronized session.\nRun calibration to measure and compensate for latency differences.',
                          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isSynchronized && sync != null && sync.offsetMs != null) ...[
                SizedBox(height: SMSpacing.lg),
                Text(
                  'Offset: ${sync.offsetMs!.toStringAsFixed(1)} ms · Drift: ${sync.driftMsPerSecond?.toStringAsFixed(2) ?? "?"} ms/s',
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
              ],
              SizedBox(height: SMSpacing.lg),
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
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
              ],
              SizedBox(height: SMSpacing.lg),
              Text(
                '[UI SCAFFOLDING — NO REAL CALIBRATION LOGIC]',
                style: SMTypography.metadata.copyWith(color: SMColors.warning),
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
          DeviceRow(
            name: isHost ? 'This Device (Host)' : 'This Device (Participant)',
            role: isHost ? 'HOST' : 'PARTICIPANT',
            roleColor: isHost ? SMColors.soundmeshBlue : SMColors.secondaryText,
            isCurrent: true,
          ),
          if (participantJoined) ...[
            Divider(color: SMColors.divider, height: SMSpacing.lg),
            DeviceRow(
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
            'Per-device connection, audio, sync, and error state not yet available',
            style: SMTypography.caption.copyWith(color: SMColors.mutedText),
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
