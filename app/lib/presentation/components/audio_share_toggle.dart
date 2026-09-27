import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/index.dart';

class AudioShareToggle extends ConsumerStatefulWidget {
  const AudioShareToggle({
    super.key,
    required this.isHost,
    this.tsx = false,
  });

  const AudioShareToggle.tsx({
    super.key,
    required this.isHost,
  }) : tsx = true;

  final bool isHost;
  final bool tsx;

  @override
  ConsumerState<AudioShareToggle> createState() =>
      _AudioShareToggleState();
}

class _AudioShareToggleState extends ConsumerState<AudioShareToggle>
    with SingleTickerProviderStateMixin {
  bool _awaitingPermissionStart = false;

  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHost) {
      return const SizedBox.shrink();
    }

    final captureState = ref.watch(captureStateProvider);
    final state = captureState.state;

    ref.listen<CaptureUiStateData>(
      captureStateProvider,
      (previous, next) {
        if (!_awaitingPermissionStart) {
          return;
        }

        if (next.state == CaptureUiState.permissionGranted) {
          _awaitingPermissionStart = false;

          ref
              .read(captureStateProvider.notifier)
              .startCaptureAndStream();
        } else if (next.state == CaptureUiState.permissionDenied ||
            next.state == CaptureUiState.failed) {
          _awaitingPermissionStart = false;
          _showPermissionDeniedGuidance();
        }
      },
    );

    if (widget.tsx) {
      return _buildTSXContent(state);
    }

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
              const SizedBox(height: SMSpacing.lg),
              _buildToggleButton(state),
              const SizedBox(height: SMSpacing.md),
              _buildStatusIndicator(state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTSXContent(CaptureUiState state) {
    final isCapturing = state == CaptureUiState.capturing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TSXColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: TSXColors.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            width: 144,
            height: 144,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  TSXColors.accent.withValues(
                    alpha: isCapturing ? 0.15 : 0.05,
                  ),
                  TSXColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SPATIAL AUDIO STREAM',
                      style: TSXTypography.metadata.copyWith(
                        color: TSXColors.secondaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  if (isCapturing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: TSXColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: TSXColors.accent.withValues(
                            alpha: 0.30,
                          ),
                        ),
                      ),
                      child: Text(
                        'LIVE • 96kHz',
                        style: TSXTypography.metadata.copyWith(
                          color: TSXColors.accent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              _buildTSXToggleButton(state),

              if (isCapturing) ...[
                const SizedBox(height: 12),
                _buildLiveStatusStrip(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTSXToggleButton(CaptureUiState state) {
    final isCapturing = state == CaptureUiState.capturing;
    final isRequesting =
        state == CaptureUiState.requestingPermission;
    final isPermissionDenied =
        state == CaptureUiState.permissionDenied;

    final isEnabled =
        !isRequesting && !isPermissionDenied;

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled
              ? () => _handleTap(state)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isCapturing
                  ? TSXColors.rose.withValues(alpha: 0.10)
                  : TSXColors.accent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCapturing
                    ? TSXColors.rose.withValues(alpha: 0.40)
                    : TSXColors.accent,
              ),
              boxShadow: isCapturing
                  ? [
                      BoxShadow(
                        color: TSXColors.rose.withValues(alpha: 0.08),
                        blurRadius: 12,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: TSXColors.accent.withValues(alpha: 0.15),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: Center(
              child: isRequesting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isCapturing
                            ? TSXColors.rose
                            : TSXColors.accentOn,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCapturing
                              ? Icons.stop
                              : Icons.play_arrow,
                          size: 20,
                          color: isCapturing
                              ? TSXColors.rose
                              : TSXColors.accentOn,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isCapturing
                              ? 'Stop Audio Share'
                              : 'Start Audio Share',
                          style: TSXTypography.labelMedium.copyWith(
                            color: isCapturing
                                ? TSXColors.rose
                                : TSXColors.accentOn,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TSXColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: TSXColors.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          _buildPulsingDot(),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Broadcasting spatial stream @ 96kHz',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TSXTypography.labelMedium.copyWith(
                color: TSXColors.primaryText,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            height: 24,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(
                    7,
                    (index) => _buildWaveBar(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveBar(int index) {
    final phase =
        (_waveController.value * math.pi * 2) +
        (index * 0.75);

    final normalized =
        ((math.sin(phase) + 1) / 2);

    final base = [
      8.0,
      14.0,
      22.0,
      30.0,
      20.0,
      12.0,
      8.0,
    ][index];

    final amplitude = [
      8.0,
      12.0,
      16.0,
      20.0,
      14.0,
      10.0,
      8.0,
    ][index];

    final height = base + (normalized * amplitude);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 4,
        height: height.clamp(8.0, 36.0),
        decoration: BoxDecoration(
          color: index == 3
              ? TSXColors.accentBright
              : TSXColors.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: index == 3
              ? [
                  BoxShadow(
                    color: TSXColors.accent.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final pulse =
            0.65 + ((math.sin(_waveController.value * math.pi * 2) + 1) / 2) * 0.35;

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TSXColors.accent.withValues(
              alpha: pulse,
            ),
            boxShadow: [
              BoxShadow(
                color: TSXColors.accent.withValues(alpha: 0.70),
                blurRadius: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleButton(CaptureUiState state) {
    final isCapturing =
        state == CaptureUiState.capturing;
    final isRequesting =
        state == CaptureUiState.requestingPermission;
    final isPermissionDenied =
        state == CaptureUiState.permissionDenied;

    final isEnabled =
        !isRequesting && !isPermissionDenied;

    return SMButton(
      text: isCapturing
          ? 'Stop Share'
          : 'Start Audio Share',
      icon: isCapturing
          ? Icons.stop
          : Icons.share,
      variant: isCapturing
          ? SMButtonVariant.danger
          : SMButtonVariant.primary,
      onPressed: isEnabled
          ? () => _handleTap(state)
          : null,
      isLoading: isRequesting,
      enabled: isEnabled,
    );
  }

  Future<void> _handleTap(
    CaptureUiState state,
  ) async {
    if (state == CaptureUiState.capturing) {
      await ref
          .read(captureStateProvider.notifier)
          .stopStreamingAndCapture();
      return;
    }

    if (state == CaptureUiState.permissionDenied) {
      _showPermissionDeniedGuidance();
      return;
    }

    if (state == CaptureUiState.requestingPermission) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    final dontShowAgain =
        prefs.getBool(
              'prepare_audio_dont_show_again',
            ) ??
            false;

    if (!mounted) return;

    if (dontShowAgain) {
      _proceedToStart();
    } else {
      _showPrepareAudioModal();
    }
  }

  void _showPrepareAudioModal() {
    var dontShowAgain = false;

    showDialog<void>(
      context: context,
      barrierColor:
          Colors.black.withValues(alpha: 0.80),
      builder: (dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Dialog(
                backgroundColor: TSXColors.surface,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: TSXColors.surfaceBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prepare Audio',
                                  style: TSXTypography.titleLarge.copyWith(
                                    color: TSXColors.primaryText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "SoundMesh will synchronize audio from the host's media app.",
                                  style: TSXTypography.caption.copyWith(
                                    color: TSXColors.secondaryText,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: Material(
                              color: TSXColors.background,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder:
                                    const CircleBorder(),
                                onTap: () =>
                                    Navigator.of(
                                      dialogContext,
                                    ).pop(),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: TSXColors.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      _buildPrepareStep(
                        number: '1',
                        title: 'Allow audio capture',
                        description:
                            'SoundMesh needs permission to capture audio from this device.',
                      ),

                      const SizedBox(height: 14),

                      _buildPrepareStep(
                        number: '2',
                        title: 'Return to your media app',
                        description:
                            'Open any supported app (YouTube, Spotify, etc.) and start playing.',
                      ),

                      const SizedBox(height: 14),

                      _buildPrepareStep(
                        number: '3',
                        title: 'Start playback',
                        description:
                            'Captured audio is distributed and played in sync.',
                      ),

                      const SizedBox(height: 18),

                      InkWell(
                        onTap: () {
                          setModalState(() {
                            dontShowAgain =
                                !dontShowAgain;
                          });
                        },
                        borderRadius:
                            BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 120,
                              ),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: dontShowAgain
                                    ? TSXColors.accent
                                    : TSXColors.background,
                                borderRadius:
                                    BorderRadius.circular(4),
                                border: Border.all(
                                  color: dontShowAgain
                                      ? TSXColors.accent
                                      : TSXColors.surfaceBorder,
                                ),
                              ),
                              child: dontShowAgain
                                  ? Icon(
                                      Icons.check,
                                      size: 11,
                                      color: TSXColors.accentOn,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Don't show this again",
                              style: TSXTypography.caption.copyWith(
                                color: TSXColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        height: 48,
                        child: Material(
                          color: TSXColors.accent,
                          borderRadius:
                              BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(12),
                            onTap: () async {
                              Navigator.of(
                                dialogContext,
                              ).pop();

                              if (dontShowAgain) {
                                final prefs =
                                    await SharedPreferences
                                        .getInstance();

                                await prefs.setBool(
                                  'prepare_audio_dont_show_again',
                                  true,
                                );
                              }

                              _proceedToStart();
                            },
                            child: Center(
                              child: Text(
                                'Continue',
                                style: TSXTypography.labelMedium.copyWith(
                                  color: TSXColors.accentOn,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPrepareStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: TSXColors.accent.withValues(
              alpha: 0.15,
            ),
            borderRadius:
                BorderRadius.circular(999),
            border: Border.all(
              color: TSXColors.accent.withValues(
                alpha: 0.40,
              ),
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TSXTypography.metadata.copyWith(
                color: TSXColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TSXTypography.labelMedium.copyWith(
                  color: TSXColors.primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TSXTypography.caption.copyWith(
                  color: TSXColors.secondaryText,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _proceedToStart() {
    final currentState =
        ref.read(captureStateProvider).state;

    if (currentState ==
        CaptureUiState.permissionGranted) {
      ref
          .read(captureStateProvider.notifier)
          .startCaptureAndStream();
    } else {
      _awaitingPermissionStart = true;

      ref
          .read(captureStateProvider.notifier)
          .requestPermission();
    }
  }

  void _showPermissionDeniedGuidance() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Audio capture permission was denied. Please enable it in system settings to use Audio Share.',
          style: TextStyle(
            color: widget.tsx
                ? TSXColors.accentOn
                : SMColors.onAccent,
          ),
        ),
        backgroundColor: widget.tsx
            ? TSXColors.error
            : SMColors.error,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Settings',
          textColor: widget.tsx
              ? TSXColors.accentOn
              : SMColors.onAccent,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    CaptureUiState state,
  ) {
    final (Color dotColor, String label, Color labelColor) =
        _getStateVisuals(state);

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
                color: dotColor.withValues(
                  alpha: 0.5,
                ),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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

  (Color, String, Color) _getStateVisuals(
    CaptureUiState state,
  ) {
    switch (state) {
      case CaptureUiState.capturing:
        return (
          SMColors.success,
          'Sharing',
          SMColors.success,
        );

      case CaptureUiState.idle:
      case CaptureUiState.stopped:
        return (
          SMColors.mutedText,
          'Not Sharing',
          SMColors.mutedText,
        );

      case CaptureUiState.requestingPermission:
        return (
          SMColors.warning,
          'Requesting Permission…',
          SMColors.warning,
        );

      case CaptureUiState.permissionGranted:
        return (
          SMColors.soundmeshBlue,
          'Permission Granted',
          SMColors.soundmeshBlue,
        );

      case CaptureUiState.permissionDenied:
        return (
          SMColors.error,
          'Permission Denied',
          SMColors.error,
        );

      case CaptureUiState.failed:
        return (
          SMColors.error,
          'Failed',
          SMColors.error,
        );
    }
  }

  String _getStateDetail(
    CaptureUiState state,
  ) {
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