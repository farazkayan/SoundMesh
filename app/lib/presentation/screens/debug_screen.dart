import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide StateProvider;
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/application/providers/output_provider.dart';
import 'package:soundmesh/application/providers/receive_provider.dart';
import 'package:soundmesh/application/providers/sync_provider.dart';
import 'package:soundmesh/application/synchronization/sync_state.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/surface.dart';
import 'package:soundmesh/presentation/debug/debug_widgets.dart';
import 'package:soundmesh/presentation/state_compat.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(applicationStateProvider);
    final captureState = ref.watch(captureStateProvider);
    final receiveState = ref.watch(receiveStateProvider);
    final syncStatusAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Debug / Diagnostics',
          style: SMTypography.heading.copyWith(color: SMColors.primaryText),
        ),
        backgroundColor: SMColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: SMColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Debug banner
              Container(
                padding: EdgeInsets.all(SMSpacing.md),
                decoration: BoxDecoration(
                  color: SMColors.warning.withValues(alpha: 0.15),
                  border: Border.all(color: SMColors.warning, width: 2),
                  borderRadius: BorderRadius.circular(SMRadius.medium),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: SMColors.warning, size: 24),
                    SizedBox(width: SMSpacing.md),
                    Expanded(
                      child: Text(
                        'DEBUG BUILD ONLY — Temporary Diagnostics Page',
                        style: SMTypography.body.copyWith(
                          color: SMColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: SMSpacing.xl),

              // Phase 11 Clock Synchronization
              _buildClockSyncSection(context, syncStatusAsync),
              SizedBox(height: SMSpacing.xxl),

              // Session Info
              _buildSessionInfoSection(context, appState),
              SizedBox(height: SMSpacing.xxl),

              // Capture Debug Section - HOST ONLY
              if (appState.isHost == true) ...[
                _buildCaptureDebugSection(context, captureState, ref),
                SizedBox(height: SMSpacing.xxl),
              ],

              // Receive Debug Section - PARTICIPANT ONLY
              if (appState.isHost != true) ...[
                _buildReceiveDebugSection(context, receiveState),
                SizedBox(height: SMSpacing.xxl),
              ],

              // Output Debug Section - shown for both
              _buildOutputDebugSection(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockSyncSection(BuildContext context, AsyncValue<SyncStatus> syncStatusAsync) {
    return SMCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_alt, color: SMColors.soundmeshBlue, size: 24),
              SizedBox(width: SMSpacing.md),
              Text(
                'Clock Synchronization',
                style: SMTypography.heading.copyWith(color: SMColors.primaryText),
              ),
            ],
          ),
          SizedBox(height: SMSpacing.lg),
          syncStatusAsync.when(
            data: (status) => _buildSyncMetrics(context, status),
            loading: () => Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SMColors.soundmeshBlue,
                  ),
                ),
                SizedBox(width: SMSpacing.md),
                Text(
                  'Loading sync status…',
                  style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                ),
              ],
            ),
            error: (e, _) => Row(
              children: [
                Icon(Icons.error_outline, color: SMColors.error, size: 20),
                SizedBox(width: SMSpacing.md),
                Expanded(
                  child: Text(
                    'Failed to load sync status: $e',
                    style: SMTypography.caption.copyWith(color: SMColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncMetrics(BuildContext context, SyncStatus status) {
    final isActive = status.state != SyncState.unsynchronized;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // State badge
        Row(
          children: [
            Text('State: ', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
            SyncStateBadge(state: status.state),
          ],
        ),
        SizedBox(height: SMSpacing.md),
        Divider(color: SMColors.divider),
        SizedBox(height: SMSpacing.md),

        // Metrics grid
        MetricRow(label: 'Valid Samples', value: '${status.validSampleCount} / 20'),
        MetricRow(label: 'Offset', value: status.offsetMs != null ? '${status.offsetMs!.toStringAsFixed(2)} ms' : 'N/A'),
        MetricRow(label: 'RTT', value: status.rttMs != null ? '${status.rttMs!.toStringAsFixed(1)} ms' : 'N/A'),
        MetricRow(label: 'Uncertainty', value: status.uncertaintyMs != null ? '${status.uncertaintyMs!.toStringAsFixed(1)} ms' : 'N/A'),
        MetricRow(label: 'Rejected Samples', value: 'N/A'),
        MetricRow(label: 'Generation', value: status.generation.toString()),
        if (!isActive) ...[
          SizedBox(height: SMSpacing.md),
          Text(
            'No active synchronization session',
            style: SMTypography.caption.copyWith(color: SMColors.mutedText),
          ),
        ],
      ],
    );
  }

  Widget _buildSessionInfoSection(BuildContext context, ApplicationState appState) {
    return SMCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Info', style: SMTypography.heading.copyWith(color: SMColors.primaryText)),
          SizedBox(height: SMSpacing.md),
          MetadataRow(label: 'Role', value: appState.isHost == true ? 'HOST' : 'PARTICIPANT'),
          MetadataRow(label: 'Room ID', value: appState.roomId ?? 'N/A'),
          MetadataRow(label: 'Session ID', value: 'N/A'),
          MetadataRow(label: 'Join Code', value: appState.joinCode ?? 'N/A'),
          MetadataRow(label: 'App State', value: appState.state.name),
        ],
      ),
    );
  }

  Widget _buildCaptureDebugSection(BuildContext context, CaptureUiStateData captureState, WidgetRef ref) {
    final notifier = ref.read(captureStateProvider.notifier);
    final state = captureState.state;
    final metadata = captureState.metadata;
    final error = captureState.error;
    final streamState = captureState.streamState;
    final streamError = captureState.streamError;

    final isCapturing = state == CaptureUiState.capturing;
    final hasPermission = state == CaptureUiState.permissionGranted || isCapturing;
    final isStreaming = streamState == 'STREAMING';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.mic, color: SMColors.soundmeshBlue, size: 24),
            SizedBox(width: SMSpacing.md),
            Text('Capture Diagnostics (Host)', style: SMTypography.heading.copyWith(color: SMColors.primaryText)),
          ],
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
                      child: Text('Battery Optimization', style: SMTypography.label.copyWith(color: SMColors.warning)),
                    ),
                  ],
                ),
                SizedBox(height: SMSpacing.xs),
                Text(
                  'For reliable background capture, allow SoundMesh to run without battery restrictions. '
                  'Otherwise, Android may stop audio capture when the app is backgrounded.',
                  style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
                ),
                SizedBox(height: SMSpacing.md),
                FilledButton.icon(
                  onPressed: () => notifier.requestIgnoreBatteryOptimizations(),
                  icon: const Icon(Icons.battery_charging_full, size: 18),
                  label: const Text('Allow Background Capture'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SMColors.warning,
                    foregroundColor: SMColors.onAccent,
                    padding: EdgeInsets.symmetric(horizontal: SMSpacing.lg, vertical: SMSpacing.md),
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
              Text('Capture State', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              CaptureStateBadge(state: state),
              SizedBox(height: SMSpacing.md),
              Divider(color: SMColors.divider),
              SizedBox(height: SMSpacing.md),
              Text('Streaming State', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              StreamingStateBadge(state: streamState ?? 'IDLE', error: streamError),
              SizedBox(height: SMSpacing.md),
              Divider(color: SMColors.divider),
              SizedBox(height: SMSpacing.md),
              Text('Live Frame Indicator', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              FrameArrivalIndicator(frameStats: captureState.frameStats, isCapturing: isCapturing),
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
                Text('Capture Metadata', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
                SizedBox(height: SMSpacing.xs),
                MetadataRow(label: 'Sample Rate', value: '${metadata.sampleRate} Hz'),
                MetadataRow(label: 'Channel Count', value: metadata.channelCount.toString()),
                MetadataRow(label: 'Session ID', value: metadata.sessionId),
                MetadataRow(label: 'Generation', value: metadata.generation.toString()),
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
                    Text('Capture Error', style: SMTypography.label.copyWith(color: SMColors.error)),
                  ],
                ),
                SizedBox(height: SMSpacing.xs),
                Text('${error.code}: ${error.message}', style: SMTypography.body.copyWith(color: SMColors.error)),
              ],
            ),
          ),
          SizedBox(height: SMSpacing.md),
        ],

        // Control Buttons
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Controls', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.md),
              Wrap(
                spacing: SMSpacing.md,
                runSpacing: SMSpacing.md,
                children: [
                  OutlinedButton.icon(
                    onPressed: state == CaptureUiState.requestingPermission ? null : () => notifier.requestPermission(),
                    icon: Icon(state == CaptureUiState.requestingPermission ? Icons.hourglass_empty : Icons.mic_none, size: 18),
                    label: Text(state == CaptureUiState.requestingPermission ? 'Requesting…' : 'Request Capture Permission'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SMColors.soundmeshBlue,
                      side: BorderSide(color: SMColors.soundmeshBlue),
                      padding: EdgeInsets.symmetric(horizontal: SMSpacing.lg, vertical: SMSpacing.md),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: hasPermission && !isCapturing ? () => notifier.startCaptureAndStream() : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Capture & Stream'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SMColors.success,
                      foregroundColor: SMColors.onAccent,
                      padding: EdgeInsets.symmetric(horizontal: SMSpacing.lg, vertical: SMSpacing.md),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isCapturing || isStreaming ? () => notifier.stopStreamingAndCapture() : null,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SMColors.error,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: SMSpacing.lg, vertical: SMSpacing.md),
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
        Row(
          children: [
            Icon(Icons.volume_up, color: SMColors.soundmeshBlue, size: 24),
            SizedBox(width: SMSpacing.md),
            Text('Output Diagnostics', style: SMTypography.heading.copyWith(color: SMColors.primaryText)),
          ],
        ),
        SizedBox(height: SMSpacing.lg),

        // State Display
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Output State', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              OutputStateBadge(state: state),
              SizedBox(height: SMSpacing.md),
              Divider(color: SMColors.divider),
              SizedBox(height: SMSpacing.md),
              Text('Buffer Status', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              BufferStatusIndicator(bufferedMs: bufferedMs, isPlaying: isPlaying),
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
                    Text('Output Error', style: SMTypography.label.copyWith(color: SMColors.error)),
                  ],
                ),
                SizedBox(height: SMSpacing.xs),
                Text(error, style: SMTypography.body.copyWith(color: SMColors.error)),
              ],
            ),
          ),
          SizedBox(height: SMSpacing.md),
        ],
      ],
    );
  }

  Widget _buildReceiveDebugSection(BuildContext context, ReceiveUiStateData receiveState) {
    final state = receiveState.state;
    final stats = receiveState.stats;
    final peakAmplitude = receiveState.peakAmplitude;
    final isSilent = receiveState.isSilent;

    final isReceiving = state == ReceiveUiState.receiving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.download, color: SMColors.soundmeshBlue, size: 24),
            SizedBox(width: SMSpacing.md),
            Text('Receive Diagnostics (Participant)', style: SMTypography.heading.copyWith(color: SMColors.primaryText)),
          ],
        ),
        SizedBox(height: SMSpacing.lg),

        // State Display
        SMCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receive State', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              ReceiveStateBadge(state: state),
              SizedBox(height: SMSpacing.md),
              Divider(color: SMColors.divider),
              SizedBox(height: SMSpacing.md),
              Text('Audio Level Meter', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              AudioLevelMeter(peakAmplitude: peakAmplitude, isSilent: isSilent, isReceiving: isReceiving),
              SizedBox(height: SMSpacing.md),
              Divider(color: SMColors.divider),
              SizedBox(height: SMSpacing.md),
              Text('Receive Stats', style: SMTypography.label.copyWith(color: SMColors.secondaryText)),
              SizedBox(height: SMSpacing.xs),
              if (stats != null) ...[
                MetadataRow(label: 'Packets Received', value: stats.packetsReceived.toString()),
                MetadataRow(label: 'Packets Lost', value: stats.packetsLost.toString()),
                MetadataRow(label: 'Out of Order', value: stats.packetsOutOfOrder.toString()),
                MetadataRow(label: 'Buffer Depth', value: '${stats.bufferDepthMs} ms'),
                MetadataRow(label: 'Loss Rate', value: '${(stats.lossRate * 100).toStringAsFixed(2)}%'),
                MetadataRow(label: 'Healthy', value: stats.isHealthy.toString()),
                MetadataRow(label: 'Peak Amplitude', value: stats.peakAmplitude.toString()),
                MetadataRow(label: 'Silent', value: stats.isSilent.toString()),
              ] else ...[
                Text('No stats available', style: SMTypography.caption.copyWith(color: SMColors.mutedText)),
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
                    Text('Receive Error', style: SMTypography.label.copyWith(color: SMColors.error)),
                  ],
                ),
                SizedBox(height: SMSpacing.xs),
                Text(receiveState.error!, style: SMTypography.body.copyWith(color: SMColors.error)),
              ],
            ),
          ),
          SizedBox(height: SMSpacing.md),
        ],
      ],
    );
  }
}