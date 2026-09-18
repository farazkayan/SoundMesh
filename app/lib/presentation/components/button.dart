import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';

enum SMButtonVariant { primary, secondary, danger }

class SMButton extends StatelessWidget {
  const SMButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.variant = SMButtonVariant.primary,
    this.enabled = true,
    this.isLoading = false,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SMButtonVariant variant;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && onPressed != null && !isLoading;

    Color foregroundColor;
    switch (variant) {
      case SMButtonVariant.primary:
        foregroundColor = SMColors.onAccent;
      case SMButtonVariant.secondary:
        foregroundColor = SMColors.primaryText;
      case SMButtonVariant.danger:
        foregroundColor = SMColors.error;
    }

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: SMDimensions.loadingSize,
        height: SMDimensions.loadingSize,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
          strokeWidth: SMDimensions.loadingStrokeWidth.toDouble(),
        ),
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: SMDimensions.iconSize),
            SizedBox(width: SMSpacing.sm),
          ],
          Text(
            text,
            style: SMTypography.button.copyWith(color: foregroundColor),
          ),
        ],
      );
    }

    // Filled treatments per the Stitch v1 export: primary actions are solid
    // accent; secondary actions are filled neutral surfaces; destructive
    // actions are a neutral surface fill with error-colored content.
    final ButtonStyle style = switch (variant) {
      SMButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: SMColors.soundmeshBlue,
        foregroundColor: SMColors.onAccent,
        disabledBackgroundColor: SMColors.disabledButtonFill,
        disabledForegroundColor: SMColors.disabledText,
      ),
      SMButtonVariant.secondary => ElevatedButton.styleFrom(
        backgroundColor: SMColors.surfaceContainer,
        foregroundColor: SMColors.primaryText,
        disabledBackgroundColor: SMColors.disabledButtonFill,
        disabledForegroundColor: SMColors.disabledText,
      ),
      SMButtonVariant.danger => ElevatedButton.styleFrom(
        backgroundColor: SMColors.surfaceHigh,
        foregroundColor: SMColors.error,
        disabledBackgroundColor: SMColors.disabledButtonFill,
        disabledForegroundColor: SMColors.disabledText,
      ),
    };

    return ElevatedButton(
      onPressed: isActive ? onPressed : null,
      style: style.merge(
        ElevatedButton.styleFrom(
          minimumSize: Size(SMDimensions.touchTarget, SMDimensions.touchTarget),
          padding: EdgeInsets.symmetric(
            horizontal: SMSpacing.xl,
            vertical: SMSpacing.md,
          ),
        ),
      ),
      child: child,
    );
  }
}
