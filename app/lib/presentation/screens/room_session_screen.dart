import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class RoomPlaybackScreen extends ConsumerWidget {
  const RoomPlaybackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Audio Session',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        backgroundColor: SMColors.background,
        elevation: 0,
      ),
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
  }

  Widget _buildContent(BuildContext context, ApplicationState appState) {
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
}