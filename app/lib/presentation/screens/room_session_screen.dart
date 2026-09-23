import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/application/providers/output_provider.dart';
import 'package:soundmesh/application/providers/receive_provider.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/empty_state.dart';
import 'package:soundmesh/presentation/components/loading_indicator.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/state_compat.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';

class RoomPlaybackScreen extends ConsumerWidget {
  const RoomPlaybackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final captureState = ref.watch(captureStateProvider);
    final receiveState = ref.watch(receiveStateProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.xl,
          ),
          child: _buildContent(
            context,
            appState,
            captureState,
            receiveState,
            ref,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ApplicationState appState,
    CaptureUiStateData captureState,
    ReceiveUiStateData receiveState,
    WidgetRef ref,
  ) {
    final sync = appState.sync;
    final syncStatus = sync?.syncState ?? SMSyncStatus.unknown;
    final isHost = appState.isHost == true;

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
        _buildSyncStatusCard(syncStatus),
        SizedBox(height: SMSpacing.xxl),
        // Receive debug section - PARTICIPANT ONLY
        if (!isHost) ...[
          _buildReceiveDebugSection(context, receiveState),
          SizedBox(height: SMSpacing.xxl),
        ],
        // Capture debug section - HOST ONLY
        if (isHost) ...[
          _buildCaptureDebugSection(context, captureState, ref),
          SizedBox(height: SMSpacing.xxl),
        ],
        // Output debug section - shown for both (both have output)
        _buildOutputDebugSection(context, ref),
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
        message:
            appState.message ?? 'Something went wrong with the audio session.',
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
      subtitle =
          'External audio is being captured, synchronized, and played on all devices.';
      icon = Icons.graphic_eq;
      iconColor = SMColors.soundmeshBlue;
    } else if (isPaused) {
      title = 'Synchronized Audio Paused';
      subtitle =
          'The external media app has paused. Synchronization is maintained at the paused position.';
      icon = Icons.graphic_eq;
      iconColor = SMColors.warning;
    } else if (isReady) {
      title = 'Devices Synchronized';
      subtitle =
          'Devices are calibrated and ready. Open your media app and start playing audio to begin the session.';
      icon = Icons.check_circle;
      iconColor = SMColors.success;
    } else if (isRoomReady) {
      title = 'Room Ready';
      subtitle =
          'Run calibration to synchronize devices, then open your media app and start playing audio.';
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
              Icon(icon, size: SMDimensions.emptyIconSize, color: iconColor),
              SizedBox(height: SMSpacing.lg),
              Text(
                title,
                style: SMTypography.heading.copyWith(
                  color: SMColors.primaryText,
                ),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: SMTypography.body.copyWith(
                  color: SMColors.secondaryText,
                ),
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
                  style: SMTypography.body.copyWith(
                    color: SMColors.primaryText,
                  ),
                ),
                Text(
                  subtitle,
                  style: SMTypography.caption.copyWith(
                    color: SMColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildCapturePreparationSection(
  BuildContext context,
  GlobalKey controlsKey,
) {
  return SMCard(
    elevated: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Prepare Audio',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        SizedBox(height: SMSpacing.sm),
        Text(
          'SoundMesh captures audio from the host\'s media app and synchronizes it across all connected devices.',
          style: SMTypography.body.copyWith(color: SMColors.secondaryText),
        ),
        SizedBox(height: SMSpacing.lg),
        _buildPreparationStep(
          number: '1',
          title: 'Allow audio capture',
          description:
              'SoundMesh needs permission to capture audio from this device so other phones can hear it too.',
        ),
        SizedBox(height: SMSpacing.md),
        _buildPreparationStep(
          number: '2',
          title: 'Return to your media app',
          description:
              'Open any supported app (YouTube, Spotify, etc.) and start playing audio.',
        ),
        SizedBox(height: SMSpacing.md),
        _buildPreparationStep(
          number: '3',
          title: 'SoundMesh synchronizes',
          description:
              'The captured audio is distributed and played in sync on all devices.',
        ),
        SizedBox(height: SMSpacing.xl),
        FilledButton.icon(
          onPressed: () {
            final context = controlsKey.currentContext;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Continue'),
          style: FilledButton.styleFrom(
            backgroundColor: SMColors.soundmeshBlue,
            foregroundColor: SMColors.onAccent,
            padding: EdgeInsets.symmetric(vertical: SMSpacing.md),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPreparationStep({
  required String number,
  required String title,
  required String description,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: SMColors.soundmeshBlue,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            number,
            style: SMTypography.caption.copyWith(
              color: SMColors.onAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      SizedBox(width: SMSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: SMTypography.bodyEmphasis.copyWith(
                color: SMColors.primaryText,
              ),
            ),
            SizedBox(height: SMSpacing.xs),
            Text(
              description,
              style: SMTypography.caption.copyWith(
                color: SMColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildCaptureDebugSection(
  BuildContext context,
  CaptureUiStateData captureState,
  WidgetRef ref,
) {
  final notifier = ref.read(captureStateProvider.notifier);
  final state = captureState.state;
  final metadata = captureState.metadata;
  final error = captureState.error;
  final streamState = captureState.streamState;
  final streamError = captureState.streamError;

  final isCapturing = state == CaptureUiState.capturing;
  final hasPermission =
      state == CaptureUiState.permissionGranted || isCapturing;
  final isStreaming = streamState == 'STREAMING';

  final controlsKey = GlobalKey();

  final showPreparation =
      state == CaptureUiState.idle || state == CaptureUiState.permissionDenied;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (showPreparation) ...[
        _buildCapturePreparationSection(context, controlsKey),
        SizedBox(height: SMSpacing.xl),
      ],
      // DEBUG BANNER
      Container(
        padding: EdgeInsets.all(SMSpacing.md),
        decoration: BoxDecoration(
          color: SMColors.warning.withValues(alpha: 0.15),
          border: Border.all(color: SMColors.warning, width: 2),
          borderRadius: BorderRadius.circular(SMRadius.medium),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: SMColors.warning,
              size: 20,
            ),
            SizedBox(width: SMSpacing.sm),
            Expanded(
              child: Text(
                'DEBUG BUILD ONLY — Temporary Capture Test UI',
                style: SMTypography.caption.copyWith(
                  color: SMColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: SMSpacing.lg),

      // Battery Optimization Banner
      if (captureState.isIgnoringBatteryOptimizations == false) ...[
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.battery_alert, color: SMColors.warning, size: 20),
                  SizedBox(width: SMSpacing.sm),
                  Expanded(
                    child: Text(
                      'Battery Optimization',
                      style: SMTypography.label.copyWith(
                        color: SMColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: SMSpacing.xs),
              Text(
                'For reliable background capture, allow SoundMesh to run without battery restrictions. '
                'Otherwise, Android may stop audio capture when the app is backgrounded.',
                style: SMTypography.caption.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
              SizedBox(height: SMSpacing.md),
              FilledButton.icon(
                onPressed: () => notifier.requestIgnoreBatteryOptimizations(),
                icon: const Icon(Icons.battery_charging_full, size: 18),
                label: const Text('Allow Background Capture'),
                style: FilledButton.styleFrom(
                  backgroundColor: SMColors.warning,
                  foregroundColor: SMColors.onAccent,
                  padding: EdgeInsets.symmetric(
                    horizontal: SMSpacing.lg,
                    vertical: SMSpacing.md,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.md),
      ],

      // State Display
      SMCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capture State',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _CaptureStateBadge(state: state),
            SizedBox(height: SMSpacing.md),
            Divider(color: SMColors.divider),
            SizedBox(height: SMSpacing.md),
            Text(
              'Streaming State',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _StreamingStateBadge(
              state: streamState ?? 'IDLE',
              error: streamError,
            ),
            SizedBox(height: SMSpacing.md),
            Divider(color: SMColors.divider),
            SizedBox(height: SMSpacing.md),
            Text(
              'Live Frame Indicator',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _FrameArrivalIndicator(
              frameStats: captureState.frameStats,
              isCapturing: isCapturing,
            ),
          ],
        ),
      ),
      SizedBox(height: SMSpacing.md),

      // Metadata Display
      if (metadata != null) ...[
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture Metadata',
                style: SMTypography.label.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
              SizedBox(height: SMSpacing.xs),
              _MetadataRow(
                label: 'Sample Rate',
                value: '${metadata.sampleRate} Hz',
              ),
              _MetadataRow(
                label: 'Channel Count',
                value: metadata.channelCount.toString(),
              ),
              _MetadataRow(label: 'Session ID', value: metadata.sessionId),
              _MetadataRow(
                label: 'Generation',
                value: metadata.generation.toString(),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.md),
      ],

      // Error Display
      if (error != null) ...[
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: SMColors.error, size: 20),
                  SizedBox(width: SMSpacing.sm),
                  Text(
                    'Capture Error',
                    style: SMTypography.label.copyWith(color: SMColors.error),
                  ),
                ],
              ),
              SizedBox(height: SMSpacing.xs),
              Text(
                '${error.code}: ${error.message}',
                style: SMTypography.body.copyWith(color: SMColors.error),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.md),
      ],

      // Control Buttons
      SMCard(
        key: controlsKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Controls',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.md),
            Wrap(
              spacing: SMSpacing.md,
              runSpacing: SMSpacing.md,
              children: [
                // Request Permission Button
                OutlinedButton.icon(
                  onPressed: state == CaptureUiState.requestingPermission
                      ? null
                      : () => notifier.requestPermission(),
                  icon: Icon(
                    state == CaptureUiState.requestingPermission
                        ? Icons.hourglass_empty
                        : Icons.mic_none,
                    size: 18,
                  ),
                  label: Text(
                    state == CaptureUiState.requestingPermission
                        ? 'Requesting…'
                        : 'Request Capture Permission',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SMColors.soundmeshBlue,
                    side: BorderSide(color: SMColors.soundmeshBlue),
                    padding: EdgeInsets.symmetric(
                      horizontal: SMSpacing.lg,
                      vertical: SMSpacing.md,
                    ),
                  ),
                ),
                // Start Capture & Stream Button
                FilledButton.icon(
                  onPressed: hasPermission && !isCapturing
                      ? () => notifier.startCaptureAndStream()
                      : null,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start Capture & Stream'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SMColors.success,
                    foregroundColor: SMColors.onAccent,
                    padding: EdgeInsets.symmetric(
                      horizontal: SMSpacing.lg,
                      vertical: SMSpacing.md,
                    ),
                  ),
                ),
                // Stop Button (stops streaming then capture)
                FilledButton.icon(
                  onPressed: isCapturing || isStreaming
                      ? () => notifier.stopStreamingAndCapture()
                      : null,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SMColors.error,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: SMSpacing.lg,
                      vertical: SMSpacing.md,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildOutputDebugSection(BuildContext context, WidgetRef ref) {
  final outputState = ref.watch(outputStateProvider);
  final state = outputState.state;
  final bufferedMs = outputState.bufferedMs;
  final error = outputState.error;

  final isPlaying = state == OutputUiState.playing;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // DEBUG BANNER
      Container(
        padding: EdgeInsets.all(SMSpacing.md),
        decoration: BoxDecoration(
          color: SMColors.warning.withValues(alpha: 0.15),
          border: Border.all(color: SMColors.warning, width: 2),
          borderRadius: BorderRadius.circular(SMRadius.medium),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: SMColors.warning,
              size: 20,
            ),
            SizedBox(width: SMSpacing.sm),
            Expanded(
              child: Text(
                'DEBUG BUILD ONLY — Output Engine Test UI',
                style: SMTypography.caption.copyWith(
                  color: SMColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: SMSpacing.lg),

      // State Display
      SMCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Output State',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _OutputStateBadge(state: state),
            SizedBox(height: SMSpacing.md),
            Divider(color: SMColors.divider),
            SizedBox(height: SMSpacing.md),
            Text(
              'Buffer Status',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _BufferStatusIndicator(
              bufferedMs: bufferedMs,
              isPlaying: isPlaying,
            ),
          ],
        ),
      ),
      SizedBox(height: SMSpacing.md),

      // Error Display
      if (error != null) ...[
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: SMColors.error, size: 20),
                  SizedBox(width: SMSpacing.sm),
                  Text(
                    'Output Error',
                    style: SMTypography.label.copyWith(color: SMColors.error),
                  ),
                ],
              ),
              SizedBox(height: SMSpacing.xs),
              Text(
                error,
                style: SMTypography.body.copyWith(color: SMColors.error),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.md),
      ],
    ],
  );
}

class _OutputStateBadge extends StatelessWidget {
  const _OutputStateBadge({required this.state});

  final OutputUiState state;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (state) {
      case OutputUiState.idle:
        bgColor = SMColors.mutedText.withValues(alpha: 0.2);
        textColor = SMColors.mutedText;
        label = 'IDLE';
        break;
      case OutputUiState.starting:
        bgColor = SMColors.warning.withValues(alpha: 0.2);
        textColor = SMColors.warning;
        label = 'STARTING';
        break;
      case OutputUiState.playing:
        bgColor = SMColors.soundmeshBlue.withValues(alpha: 0.2);
        textColor = SMColors.soundmeshBlue;
        label = 'PLAYING';
        break;
      case OutputUiState.underrun:
        bgColor = SMColors.warning.withValues(alpha: 0.2);
        textColor = SMColors.warning;
        label = 'UNDERRUN';
        break;
      case OutputUiState.stopped:
        bgColor = SMColors.secondaryText.withValues(alpha: 0.2);
        textColor = SMColors.secondaryText;
        label = 'STOPPED';
        break;
      case OutputUiState.failed:
        bgColor = SMColors.error.withValues(alpha: 0.2);
        textColor = SMColors.error;
        label = 'FAILED';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SMSpacing.md,
        vertical: SMSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(SMRadius.small),
        border: Border.all(color: textColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: SMTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BufferStatusIndicator extends StatelessWidget {
  const _BufferStatusIndicator({
    required this.bufferedMs,
    required this.isPlaying,
  });

  final int bufferedMs;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    if (!isPlaying) {
      return Row(
        children: [
          Icon(
            Icons.radio_button_unchecked,
            color: SMColors.mutedText,
            size: 16,
          ),
          SizedBox(width: SMSpacing.sm),
          Text(
            'Not playing — start streaming to see buffer status',
            style: SMTypography.caption.copyWith(color: SMColors.mutedText),
          ),
        ],
      );
    }

    Color indicatorColor;
    String statusText;
    String detailText;

    if (bufferedMs < 50) {
      indicatorColor = SMColors.error;
      statusText = 'LOW BUFFER';
      detailText = 'Buffer: ${bufferedMs}ms (target ~200ms)';
    } else if (bufferedMs < 100) {
      indicatorColor = SMColors.warning;
      statusText = 'BUFFERING';
      detailText = 'Buffer: ${bufferedMs}ms (target ~200ms)';
    } else {
      indicatorColor = SMColors.success;
      statusText = 'HEALTHY';
      detailText = 'Buffer: ${bufferedMs}ms';
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: indicatorColor,
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        SizedBox(width: SMSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: SMTypography.body.copyWith(
                  color: indicatorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                detailText,
                style: SMTypography.caption.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaptureStateBadge extends StatelessWidget {
  const _CaptureStateBadge({required this.state});

  final CaptureUiState state;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (state) {
      case CaptureUiState.idle:
        bgColor = SMColors.mutedText.withValues(alpha: 0.2);
        textColor = SMColors.mutedText;
        label = 'IDLE';
        break;
      case CaptureUiState.requestingPermission:
        bgColor = SMColors.warning.withValues(alpha: 0.2);
        textColor = SMColors.warning;
        label = 'REQUESTING PERMISSION';
        break;
      case CaptureUiState.permissionGranted:
        bgColor = SMColors.success.withValues(alpha: 0.2);
        textColor = SMColors.success;
        label = 'PERMISSION GRANTED';
        break;
      case CaptureUiState.permissionDenied:
        bgColor = SMColors.error.withValues(alpha: 0.2);
        textColor = SMColors.error;
        label = 'PERMISSION DENIED';
        break;
      case CaptureUiState.capturing:
        bgColor = SMColors.soundmeshBlue.withValues(alpha: 0.2);
        textColor = SMColors.soundmeshBlue;
        label = 'CAPTURING';
        break;
      case CaptureUiState.stopped:
        bgColor = SMColors.secondaryText.withValues(alpha: 0.2);
        textColor = SMColors.secondaryText;
        label = 'STOPPED';
        break;
      case CaptureUiState.failed:
        bgColor = SMColors.error.withValues(alpha: 0.2);
        textColor = SMColors.error;
        label = 'FAILED';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SMSpacing.md,
        vertical: SMSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(SMRadius.small),
        border: Border.all(color: textColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: SMTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StreamingStateBadge extends StatelessWidget {
  const _StreamingStateBadge({required this.state, this.error});

  final String state;
  final CaptureError? error;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    final captureError = error;
    if (captureError != null) {
      bgColor = SMColors.error.withValues(alpha: 0.2);
      textColor = SMColors.error;
      label = '${captureError.code}: ${captureError.message}';
    } else {
      switch (state) {
        case 'IDLE':
          bgColor = SMColors.mutedText.withValues(alpha: 0.2);
          textColor = SMColors.mutedText;
          label = 'IDLE';
          break;
        case 'STREAMING':
          bgColor = SMColors.soundmeshBlue.withValues(alpha: 0.2);
          textColor = SMColors.soundmeshBlue;
          label = 'STREAMING';
          break;
        case 'STOPPED':
          bgColor = SMColors.secondaryText.withValues(alpha: 0.2);
          textColor = SMColors.secondaryText;
          label = 'STOPPED';
          break;
        case 'FAILED':
          bgColor = SMColors.error.withValues(alpha: 0.2);
          textColor = SMColors.error;
          label = 'FAILED';
          break;
        default:
          bgColor = SMColors.mutedText.withValues(alpha: 0.2);
          textColor = SMColors.mutedText;
          label = state;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SMSpacing.md,
        vertical: SMSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(SMRadius.small),
        border: Border.all(color: textColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: SMTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FrameArrivalIndicator extends StatelessWidget {
  const _FrameArrivalIndicator({
    required this.frameStats,
    required this.isCapturing,
  });

  final FrameArrivalStats? frameStats;
  final bool isCapturing;

  @override
  Widget build(BuildContext context) {
    if (!isCapturing || frameStats == null) {
      return Row(
        children: [
          Icon(
            Icons.radio_button_unchecked,
            color: SMColors.mutedText,
            size: 16,
          ),
          SizedBox(width: SMSpacing.sm),
          Text(
            'Not capturing — start capture to see frame arrival',
            style: SMTypography.caption.copyWith(color: SMColors.mutedText),
          ),
        ],
      );
    }

    // Three-way distinction:
    // 1. No frames arriving (isReceivingAudio = false)
    // 2. Frames arriving but silent (isSilent = true)
    // 3. Frames with real audio (isReceivingAudio = true && isSilent = false)
    final isReceiving = frameStats!.isReceivingAudio;
    final isSilent = frameStats!.isSilent;
    final hasFrames = isReceiving;

    Color indicatorColor;
    String statusText;
    String detailText;

    if (!hasFrames) {
      indicatorColor = SMColors.error;
      statusText = 'NO FRAMES ARRIVING';
      detailText = 'Capture may have failed or been interrupted';
    } else if (isSilent) {
      indicatorColor = SMColors.warning;
      statusText = 'SILENT — NO AUDIO DETECTED';
      detailText = 'Capturing, but no audio content above threshold';
    } else {
      indicatorColor = SMColors.success;
      statusText = 'RECEIVING AUDIO';
      detailText = 'Real audio content detected';
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: indicatorColor,
            boxShadow: hasFrames
                ? [
                    BoxShadow(
                      color: indicatorColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(width: SMSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: SMTypography.body.copyWith(
                  color: indicatorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Frames: ${frameStats!.totalFrames} | ${frameStats!.framesPerSecond} fps | ${frameStats!.bytesPerSecond} B/s | Peak: ${frameStats!.peakAmplitude} | Silent: ${frameStats!.silentFrames}',
                style: SMTypography.caption.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
              Text(
                detailText,
                style: SMTypography.caption.copyWith(color: SMColors.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SMSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: SMTypography.caption.copyWith(
                color: SMColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: SMTypography.caption.copyWith(
                color: SMColors.primaryText,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildReceiveDebugSection(
  BuildContext context,
  ReceiveUiStateData receiveState,
) {
  final state = receiveState.state;
  final stats = receiveState.stats;
  final peakAmplitude = receiveState.peakAmplitude;
  final isSilent = receiveState.isSilent;

  final isReceiving = state == ReceiveUiState.receiving;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // DEBUG BANNER
      Container(
        padding: EdgeInsets.all(SMSpacing.md),
        decoration: BoxDecoration(
          color: SMColors.warning.withValues(alpha: 0.15),
          border: Border.all(color: SMColors.warning, width: 2),
          borderRadius: BorderRadius.circular(SMRadius.medium),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: SMColors.warning,
              size: 20,
            ),
            SizedBox(width: SMSpacing.sm),
            Expanded(
              child: Text(
                'DEBUG BUILD ONLY — Receive Engine Test UI',
                style: SMTypography.caption.copyWith(
                  color: SMColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: SMSpacing.lg),

      // State Display
      SMCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receive State',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _ReceiveStateBadge(state: state),
            SizedBox(height: SMSpacing.md),
            Divider(color: SMColors.divider),
            SizedBox(height: SMSpacing.md),
            Text(
              'Audio Level Meter',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            _AudioLevelMeter(
              peakAmplitude: peakAmplitude,
              isSilent: isSilent,
              isReceiving: isReceiving,
            ),
            SizedBox(height: SMSpacing.md),
            Divider(color: SMColors.divider),
            SizedBox(height: SMSpacing.md),
            Text(
              'Receive Stats',
              style: SMTypography.label.copyWith(color: SMColors.secondaryText),
            ),
            SizedBox(height: SMSpacing.xs),
            if (stats != null) ...[
              _MetadataRow(
                label: 'Packets Received',
                value: stats.packetsReceived.toString(),
              ),
              _MetadataRow(
                label: 'Packets Lost',
                value: stats.packetsLost.toString(),
              ),
              _MetadataRow(
                label: 'Out of Order',
                value: stats.packetsOutOfOrder.toString(),
              ),
              _MetadataRow(
                label: 'Buffer Depth',
                value: '${stats.bufferDepthMs} ms',
              ),
              _MetadataRow(
                label: 'Loss Rate',
                value: '${(stats.lossRate * 100).toStringAsFixed(2)}%',
              ),
              _MetadataRow(label: 'Healthy', value: stats.isHealthy.toString()),
              _MetadataRow(
                label: 'Peak Amplitude',
                value: stats.peakAmplitude.toString(),
              ),
              _MetadataRow(label: 'Silent', value: stats.isSilent.toString()),
            ] else ...[
              Text(
                'No stats available',
                style: SMTypography.caption.copyWith(color: SMColors.mutedText),
              ),
            ],
          ],
        ),
      ),
      SizedBox(height: SMSpacing.md),

      // Error Display
      if (receiveState.error != null) ...[
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: SMColors.error, size: 20),
                  SizedBox(width: SMSpacing.sm),
                  Text(
                    'Receive Error',
                    style: SMTypography.label.copyWith(color: SMColors.error),
                  ),
                ],
              ),
              SizedBox(height: SMSpacing.xs),
              Text(
                receiveState.error!,
                style: SMTypography.body.copyWith(color: SMColors.error),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.md),
      ],
    ],
  );
}

class _ReceiveStateBadge extends StatelessWidget {
  const _ReceiveStateBadge({required this.state});

  final ReceiveUiState state;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (state) {
      case ReceiveUiState.idle:
        bgColor = SMColors.mutedText.withValues(alpha: 0.2);
        textColor = SMColors.mutedText;
        label = 'IDLE';
        break;
      case ReceiveUiState.receiving:
        bgColor = SMColors.soundmeshBlue.withValues(alpha: 0.2);
        textColor = SMColors.soundmeshBlue;
        label = 'RECEIVING';
        break;
      case ReceiveUiState.stopped:
        bgColor = SMColors.secondaryText.withValues(alpha: 0.2);
        textColor = SMColors.secondaryText;
        label = 'STOPPED';
        break;
      case ReceiveUiState.failed:
        bgColor = SMColors.error.withValues(alpha: 0.2);
        textColor = SMColors.error;
        label = 'FAILED';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SMSpacing.md,
        vertical: SMSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(SMRadius.small),
        border: Border.all(color: textColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: SMTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AudioLevelMeter extends StatelessWidget {
  const _AudioLevelMeter({
    required this.peakAmplitude,
    required this.isSilent,
    required this.isReceiving,
  });

  final int peakAmplitude;
  final bool isSilent;
  final bool isReceiving;

  @override
  Widget build(BuildContext context) {
    // Normalize 0-32767 to 0.0-1.0
    // Only show meter when receiving, otherwise show empty
    final fillRatio = isReceiving
        ? (peakAmplitude / 32767.0).clamp(0.0, 1.0)
        : 0.0;
    final displaySilent = !isReceiving || isSilent;

    Color meterColor;
    if (!isReceiving) {
      meterColor = SMColors.mutedText;
    } else if (isSilent) {
      meterColor = SMColors.warning;
    } else if (fillRatio > 0.7) {
      meterColor = SMColors.error; // Hot - clipping risk
    } else if (fillRatio > 0.4) {
      meterColor = SMColors.success;
    } else {
      meterColor = SMColors.soundmeshBlue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal VU meter bar
        Container(
          height: 24,
          width: double.infinity,
          decoration: BoxDecoration(
            color: SMColors.surface,
            borderRadius: BorderRadius.circular(SMRadius.small),
            border: Border.all(color: SMColors.divider),
          ),
          child: Stack(
            children: [
              // Background track
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: SMColors.surface,
                  borderRadius: BorderRadius.circular(SMRadius.small),
                ),
              ),
              // Animated fill bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                curve: Curves.easeOut,
                width: double.infinity,
                height: double.infinity,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fillRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: meterColor,
                      borderRadius: BorderRadius.circular(SMRadius.small),
                    ),
                  ),
                ),
              ),
              // Center label
              Center(
                child: Text(
                  isReceiving
                      ? (displaySilent
                            ? 'SILENT'
                            : '${(fillRatio * 100).toInt()}%')
                      : 'STOPPED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: SMColors.primaryText,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SMSpacing.xs),
        // Detail text
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: meterColor,
              ),
            ),
            SizedBox(width: SMSpacing.sm),
            Expanded(
              child: Text(
                isReceiving
                    ? (displaySilent
                          ? 'Receiving — silent (peak: $peakAmplitude)'
                          : 'Receiving — audio active (peak: $peakAmplitude / 32767)')
                    : 'Not receiving — meter at zero',
                style: SMTypography.caption.copyWith(
                  color: SMColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
