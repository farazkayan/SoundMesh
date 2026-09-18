import 'package:flutter/material.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'package:soundmesh/presentation/components/button.dart';
import 'package:soundmesh/presentation/components/surface.dart';

class RoomPreparationScreen extends StatelessWidget {
  const RoomPreparationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: SMSpacing.xl, vertical: SMSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preparation',
                style: SMTypography.largeTitle.copyWith(color: SMColors.primaryText),
              ),
              SizedBox(height: SMSpacing.md),
              Text(
                'Preparing devices for synchronized session.',
                style: SMTypography.body.copyWith(color: SMColors.secondaryText),
              ),
              SizedBox(height: SMSpacing.xl),
              SMCard(
                elevated: true,
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: SMDimensions.emptyIconSize,
                      color: SMColors.soundmeshBlue,
                    ),
                    SizedBox(height: SMSpacing.lg),
                    Text(
                      'Preparing everyone…',
                      style: SMTypography.heading.copyWith(color: SMColors.primaryText),
                    ),
                    SizedBox(height: SMSpacing.md),
                    Text(
                      'Audio is being distributed and devices are being readied.\nThis screen shows real-time preparation progress.',
                      textAlign: TextAlign.center,
                      style: SMTypography.body.copyWith(color: SMColors.secondaryText),
                    ),
                    SizedBox(height: SMSpacing.xl),
                    Column(
                      children: [
                        _PreparationStep(
                          label: 'Audio Ready',
                          status: _StepStatus.pending,
                        ),
                        _PreparationStep(
                          label: 'Devices Ready',
                          status: _StepStatus.pending,
                        ),
                        _PreparationStep(
                          label: 'Sync Ready',
                          status: _StepStatus.pending,
                        ),
                      ],
                    ),
                    SizedBox(height: SMSpacing.lg),
                    Text(
                      '[UI SCAFFOLDING — NO REAL PREPARATION LOGIC]',
                      style: SMTypography.metadata.copyWith(color: SMColors.warning),
                    ),
                  ],
                ),
              ),
              SizedBox(height: SMSpacing.xl),
              SMButton(
                text: 'Back to Room',
                variant: SMButtonVariant.secondary,
                onPressed: () => Navigator.pushReplacementNamed(context, AppRouter.roomDashboard),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreparationStep extends StatelessWidget {
  const _PreparationStep({required this.label, required this.status});

  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (status) {
      case _StepStatus.complete:
        icon = Icons.check_circle;
        color = SMColors.success;
        break;
      case _StepStatus.active:
        icon = Icons.hourglass_top;
        color = SMColors.soundmeshBlue;
        break;
      case _StepStatus.pending:
        icon = Icons.radio_button_unchecked;
        color = SMColors.mutedText;
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: SMSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: SMSpacing.md),
          Text(
            label,
            style: SMTypography.body.copyWith(
              color: status == _StepStatus.pending ? SMColors.secondaryText : SMColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepStatus { pending, active, complete }