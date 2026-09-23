import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/application/providers/capture_provider.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/surface.dart';

class BackgroundUsageRequiredModal extends ConsumerWidget {
  const BackgroundUsageRequiredModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureState = ref.watch(captureStateProvider);
    final notifier = ref.read(captureStateProvider.notifier);

    // Only show if background usage is NOT allowed
    if (captureState.isIgnoringBatteryOptimizations == true) {
      return const SizedBox.shrink();
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Full-screen scrim - blocks all interaction
          GestureDetector(
            onTap: () {}, // Consumes taps, prevents dismissal
            child: Container(
              color: SMColors.scrim,
            ),
          ),
          // Modal dialog centered with proper constraints
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - SMSpacing.xl * 2,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: SMSpacing.xl),
                child: SMCard(
                  elevated: true,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Icon and Title
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: SMColors.warning.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.battery_alert,
                                color: SMColors.warning,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: SMSpacing.md),
                            Expanded(
                              child: Text(
                                'Background usage required',
                                style: SMTypography.title.copyWith(
                                  color: SMColors.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: SMSpacing.lg),

                        // Explanation
                        Text(
                          'SoundMesh requires permission to run in the background to reliably capture and synchronize audio across devices. Without this, Android may stop audio capture when the screen turns off or the app is minimized, breaking the synchronized session.',
                          style: SMTypography.body.copyWith(
                            color: SMColors.secondaryText,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: SMSpacing.md),

                        Text(
                          'This is required for SoundMesh to work correctly — not an optional recommendation.',
                          style: SMTypography.body.copyWith(
                            color: SMColors.warning,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: SMSpacing.xl),

                        // Primary button
                        SMButton(
                          text: 'Allow background usage',
                          icon: Icons.settings,
                          variant: SMButtonVariant.primary,
                          onPressed: () async {
                            await notifier.requestIgnoreBatteryOptimizations();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}