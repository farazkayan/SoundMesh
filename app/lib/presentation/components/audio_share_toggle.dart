import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/index.dart';
import 'package:soundmesh/application/providers/capture_provider.dart';

class AudioShareToggle extends ConsumerStatefulWidget {
  const AudioShareToggle({super.key, required this.isHost});

  final bool isHost;

  @override
  ConsumerState<AudioShareToggle> createState() => _AudioShareToggleState();
}

class _AudioShareToggleState extends ConsumerState<AudioShareToggle> {
  bool _awaitingPermissionStart = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isHost) {
      return const SizedBox.shrink();
    }

    final captureState = ref.watch(captureStateProvider);
    final state = captureState.state;

    ref.listen<CaptureUiStateData>(captureStateProvider, (previous, next) {
      if (_awaitingPermissionStart) {
        if (next.state == CaptureUiState.permissionGranted) {
          _awaitingPermissionStart = false;
          ref.read(captureStateProvider.notifier).startCaptureAndStream();
        } else if (next.state == CaptureUiState.permissionDenied ||
            next.state == CaptureUiState.failed) {
          _awaitingPermissionStart = false;
          _showPermissionDeniedGuidance(context);
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SMCard(
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Audio Share',
                style: SMTypography.heading.copyWith(
                  color: SMColors.primaryText,
                ),
              ),
              SizedBox(height: SMSpacing.lg),
              _buildToggleButton(context, state),
              SizedBox(height: SMSpacing.md),
              _buildStatusIndicator(context, state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(BuildContext context, CaptureUiState state) {
    final isCapturing = state == CaptureUiState.capturing;
    final isRequesting = state == CaptureUiState.requestingPermission;
    final isPermissionDenied = state == CaptureUiState.permissionDenied;

    final bool isLoading = isRequesting;
    final bool isEnabled = !isRequesting && !isPermissionDenied;

    return SMButton(
      text: isCapturing ? 'Stop Share' : 'Start Audio Share',
      icon: isCapturing ? Icons.stop : Icons.share,
      variant: isCapturing ? SMButtonVariant.danger : SMButtonVariant.primary,
      onPressed: isEnabled ? () => _handleTap(context, state) : null,
      isLoading: isLoading,
      enabled: isEnabled,
    );
  }

  Future<void> _handleTap(BuildContext context, CaptureUiState state) async {
    if (state == CaptureUiState.capturing) {
      await ref.read(captureStateProvider.notifier).stopStreamingAndCapture();
      return;
    }

    if (state == CaptureUiState.permissionDenied) {
      _showPermissionDeniedGuidance(context);
      return;
    }

    if (state == CaptureUiState.requestingPermission) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final dontShowAgain =
        prefs.getBool('prepare_audio_dont_show_again') ?? false;

    if (!mounted) return;

    if (dontShowAgain) {
      _proceedToStart();
    } else {
      _showPrepareAudioModal(this.context);
    }
  }

  void _showPrepareAudioModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PrepareAudioModal(
        onContinue: (dontShowAgain) async {
          if (dontShowAgain) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('prepare_audio_dont_show_again', true);
          }
          _proceedToStart();
        },
      ),
    );
  }

  void _proceedToStart() {
    final currentState = ref.read(captureStateProvider).state;

    if (currentState == CaptureUiState.permissionGranted) {
      ref.read(captureStateProvider.notifier).startCaptureAndStream();
    } else {
      _awaitingPermissionStart = true;
      ref.read(captureStateProvider.notifier).requestPermission();
    }
  }

  void _showPermissionDeniedGuidance(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Audio capture permission was denied. Please enable it in system settings to use Audio Share.',
          style: TextStyle(color: SMColors.onAccent),
        ),
        backgroundColor: SMColors.error,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Settings',
          textColor: SMColors.onAccent,
          onPressed: () {
            // To do: Open app settings
          },
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, CaptureUiState state) {
    final (Color dotColor, String label, Color labelColor) = _getStateVisuals(
      state,
    );

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
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
                label,
                style: SMTypography.body.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _getStateDetail(state),
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

  (Color, String, Color) _getStateVisuals(CaptureUiState state) {
    switch (state) {
      case CaptureUiState.capturing:
        return (SMColors.success, 'Sharing', SMColors.success);
      case CaptureUiState.idle:
      case CaptureUiState.stopped:
        return (SMColors.mutedText, 'Not Sharing', SMColors.mutedText);
      case CaptureUiState.requestingPermission:
        return (SMColors.warning, 'Requesting Permission…', SMColors.warning);
      case CaptureUiState.permissionGranted:
        return (
          SMColors.soundmeshBlue,
          'Permission Granted',
          SMColors.soundmeshBlue,
        );
      case CaptureUiState.permissionDenied:
        return (SMColors.error, 'Permission Denied', SMColors.error);
      case CaptureUiState.failed:
        return (SMColors.error, 'Failed', SMColors.error);
    }
  }

  String _getStateDetail(CaptureUiState state) {
    switch (state) {
      case CaptureUiState.capturing:
        return 'Audio is being captured and shared with connected devices';
      case CaptureUiState.idle:
        return 'Ready to start sharing audio from your media app';
      case CaptureUiState.stopped:
        return 'Audio share was stopped. Tap to start again';
      case CaptureUiState.requestingPermission:
        return 'Waiting for permission response';
      case CaptureUiState.permissionGranted:
        return 'Permission granted. Ready to start sharing';
      case CaptureUiState.permissionDenied:
        return 'Permission was denied. Enable in system settings';
      case CaptureUiState.failed:
        return 'An error occurred. Tap to retry';
    }
  }
}
