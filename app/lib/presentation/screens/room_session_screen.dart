import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class RoomPlaybackScreen extends StatelessWidget {
  const RoomPlaybackScreen({super.key});

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
    final sync = appState.sync;
    final syncStatus = sync?.syncState ?? SMSyncStatus.unknown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Audio Session',
          style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.md),
        Text(
          'Live audio captured from the host\'s external app and synchronized across the room.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.xxl),
        _buildSessionStatus(context, appState),
        SizedBox(height: SMSpacing.xl),
        _buildSyncStatusCard(syncStatus),
        SizedBox(height: SMSpacing.xxl),
      ],
    );
  }

  Widget _buildSessionStatus(BuildContext context, ApplicationState appState) {
    final state = appState.state;

    if (state == SMAppState.preparing) {
      return Column(
        children: [
          SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
          SizedBox(height: SMSpacing.lg),
          Text(
            appState.message ?? 'Preparing session…',
            textAlign: TextAlign.center,
            style: SMTypography.heading.copyWith(color: SMColors.primaryText),
          ),
          SizedBox(height: SMSpacing.md),
          Text(
            'Preparing devices and audio pipeline for synchronized capture.',
            textAlign: TextAlign.center,
            style: SMTypography.body.copyWith(color: SMColors.secondaryText),
          ),
          SizedBox(height: SMSpacing.xl),
        ],
      );
    }

    if (state == SMAppState.stopping) {
      return Column(
        children: [
          SMLoadingIndicator(size: SMDimensions.emptyIconSize * 0.8),
          SizedBox(height: SMSpacing.lg),
          Text(
            appState.message ?? 'Stopping session…',
            textAlign: TextAlign.center,
            style: SMTypography.heading.copyWith(color: SMColors.primaryText),
          ),
          SizedBox(height: SMSpacing.md),
          Text(
            'Winding down the synchronized audio session.',
            textAlign: TextAlign.center,
            style: SMTypography.body.copyWith(color: SMColors.secondaryText),
          ),
          SizedBox(height: SMSpacing.xl),
        ],
      );
    }

    if (state == SMAppState.error) {
      return SMEmptyState.error(
        title: 'Session Error',
        message: appState.message ?? 'Something went wrong with the audio session.',
        icon: Icons.error_outline,
        onRetry: () => StateProvider.of(context).leaveRoom(),
      );
    }

    // roomReady, ready, playing, paused, idle, etc.
    final isActive = state == SMAppState.playing;
    final isPaused = state == SMAppState.paused;
    final isReady = state == SMAppState.ready;
    final isRoomReady = state == SMAppState.roomReady;

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    if (isActive) {
      title = 'Synchronized Audio Active';
      subtitle = 'External audio is being captured, synchronized, and played on all devices.';
      icon = Icons.graphic_eq;
      iconColor = SMColors.soundmeshBlue;
    } else if (isPaused) {
      title = 'Synchronized Audio Paused';
      subtitle = 'The external media app has paused. Synchronization is maintained at the paused position.';
      icon = Icons.graphic_eq;
      iconColor = SMColors.warning;
    } else if (isReady) {
      title = 'Devices Synchronized';
      subtitle = 'Devices are calibrated and ready. Open your media app and start playing audio to begin the session.';
      icon = Icons.check_circle;
      iconColor = SMColors.success;
    } else if (isRoomReady) {
      title = 'Room Ready';
      subtitle = 'Run calibration to synchronize devices, then open your media app and start playing audio.';
      icon = Icons.radio_button_unchecked;
      iconColor = SMColors.mutedText;
    } else {
      title = 'No Active Session';
      subtitle = 'Create or join a room to begin a synchronized audio session.';
      icon = Icons.radio_button_unchecked;
      iconColor = SMColors.mutedText;
    }

    return Column(
      children: [
        SMCard(
          elevated: true,
          child: Column(
            children: [
              Icon(
                icon,
                size: SMDimensions.emptyIconSize,
                color: iconColor,
              ),
              SizedBox(height: SMSpacing.lg),
              Text(
                title,
                style: SMTypography.heading.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.lg),
              const Text(
                '[UI SCAFFOLDING — NO REAL CAPTURE DATA]',
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
      ],
    );
  }

  Widget _buildSyncStatusCard(SMSyncStatus syncStatus) {
    IconData icon;
    String title;
    String subtitle;
    Color iconColor;

    switch (syncStatus) {
      case SMSyncStatus.synchronized:
        icon = Icons.sync;
        title = 'Synchronized';
        subtitle = 'Devices are calibrated and in sync.';
        iconColor = SMColors.success;
      case SMSyncStatus.calibrating:
        icon = Icons.sync;
        title = 'Calibrating';
        subtitle = 'Measuring and compensating latency differences.';
        iconColor = SMColors.warning;
      case SMSyncStatus.resynchronizing:
        icon = Icons.sync;
        title = 'Resynchronizing';
        subtitle = 'Correcting synchronization drift.';
        iconColor = SMColors.warning;
      case SMSyncStatus.degraded:
        icon = Icons.warning;
        title = 'Sync Degraded';
        subtitle = 'Synchronization quality has dropped.';
        iconColor = SMColors.warning;
      case SMSyncStatus.connectionLost:
        icon = Icons.sync_disabled;
        title = 'Connection Lost';
        subtitle = 'One or more devices have disconnected.';
        iconColor = SMColors.error;
      case SMSyncStatus.preparing:
        icon = Icons.sync;
        title = 'Preparing Sync';
        subtitle = 'Getting devices ready for calibration.';
        iconColor = SMColors.warning;
      case SMSyncStatus.unknown:
        icon = Icons.sync_disabled;
        title = 'Not Synchronized';
        subtitle = 'Devices must be calibrated before the session starts.';
        iconColor = SMColors.warning;
    }

    return SMCard(
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          SizedBox(width: SMSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SMTypography.body.copyWith(color: SMColors.primaryText),
                ),
                Text(
                  subtitle,
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}