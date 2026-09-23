// Shared debug UI components extracted from RoomPlaybackScreen
// for use in both RoomPlaybackScreen and DebugScreen.

import 'package:flutter/material.dart';
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/application/providers/output_provider.dart';
import 'package:soundmesh/application/providers/receive_provider.dart';
import 'package:soundmesh/application/synchronization/sync_state.dart';
import 'package:soundmesh/src/soundmesh_messages.g.dart';
import 'package:soundmesh/core/design_system/index.dart';

class MetadataRow extends StatelessWidget {
  const MetadataRow({
    super.key,
    required this.label,
    required this.value,
  });

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
              style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
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

class CaptureStateBadge extends StatelessWidget {
  const CaptureStateBadge({
    super.key,
    required this.state,
  });

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
      padding: EdgeInsets.symmetric(horizontal: SMSpacing.md, vertical: SMSpacing.sm),
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

class StreamingStateBadge extends StatelessWidget {
  const StreamingStateBadge({
    super.key,
    required this.state,
    this.error,
  });

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
      padding: EdgeInsets.symmetric(horizontal: SMSpacing.md, vertical: SMSpacing.sm),
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

class OutputStateBadge extends StatelessWidget {
  const OutputStateBadge({
    super.key,
    required this.state,
  });

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
      padding: EdgeInsets.symmetric(horizontal: SMSpacing.md, vertical: SMSpacing.sm),
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

class ReceiveStateBadge extends StatelessWidget {
  const ReceiveStateBadge({
    super.key,
    required this.state,
  });

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
      padding: EdgeInsets.symmetric(horizontal: SMSpacing.md, vertical: SMSpacing.sm),
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

class FrameArrivalIndicator extends StatelessWidget {
  const FrameArrivalIndicator({
    super.key,
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
                style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
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

class AudioLevelMeter extends StatelessWidget {
  const AudioLevelMeter({
    super.key,
    required this.peakAmplitude,
    required this.isSilent,
    required this.isReceiving,
  });

  final int peakAmplitude;
  final bool isSilent;
  final bool isReceiving;

  @override
  Widget build(BuildContext context) {
    final fillRatio = isReceiving ? (peakAmplitude / 32767.0).clamp(0.0, 1.0) : 0.0;
    final displaySilent = !isReceiving || isSilent;

    Color meterColor;
    if (!isReceiving) {
      meterColor = SMColors.mutedText;
    } else if (isSilent) {
      meterColor = SMColors.warning;
    } else if (fillRatio > 0.7) {
      meterColor = SMColors.error;
    } else if (fillRatio > 0.4) {
      meterColor = SMColors.success;
    } else {
      meterColor = SMColors.soundmeshBlue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: SMColors.surface,
                  borderRadius: BorderRadius.circular(SMRadius.small),
                ),
              ),
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
              Center(
                child: Text(
                  isReceiving
                      ? (displaySilent ? 'SILENT' : '${(fillRatio * 100).toInt()}%')
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
                style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BufferStatusIndicator extends StatelessWidget {
  const BufferStatusIndicator({
    super.key,
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
                style: SMTypography.caption.copyWith(color: SMColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SyncStateBadge extends StatelessWidget {
  const SyncStateBadge({
    super.key,
    required this.state,
  });

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (state) {
      case SyncState.unsynchronized:
        bgColor = SMColors.mutedText.withValues(alpha: 0.2);
        textColor = SMColors.mutedText;
        label = 'UNSYNCHRONIZED';
        break;
      case SyncState.synchronizing:
        bgColor = SMColors.warning.withValues(alpha: 0.2);
        textColor = SMColors.warning;
        label = 'SYNCHRONIZING';
        break;
      case SyncState.synchronized:
        bgColor = SMColors.success.withValues(alpha: 0.2);
        textColor = SMColors.success;
        label = 'SYNCHRONIZED';
        break;
      case SyncState.degraded:
        bgColor = SMColors.warning.withValues(alpha: 0.2);
        textColor = SMColors.warning;
        label = 'DEGRADED';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: SMSpacing.md, vertical: SMSpacing.sm),
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

class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
  });

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
            width: 140,
            child: Text(label, style: SMTypography.caption.copyWith(color: SMColors.secondaryText)),
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