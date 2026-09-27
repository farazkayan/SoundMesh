import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'tsx_visual_tokens.dart';

enum SMButtonVariant {
  primary,
  secondary,
  danger,
  // TSX variants
  tsxPrimary,
  tsxSecondary,
  tsxDanger,
}

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
    final isTSX = _isTSXVariant(variant);

    Color foregroundColor;
    if (isTSX) {
      switch (variant) {
        case SMButtonVariant.tsxPrimary:
          foregroundColor = TSXColors.accentOn;
          break;
        case SMButtonVariant.tsxSecondary:
          foregroundColor = TSXColors.primaryText;
          break;
        case SMButtonVariant.tsxDanger:
          foregroundColor = TSXColors.error;
          break;
        default:
          foregroundColor = TSXColors.primaryText;
      }
    } else {
      switch (variant) {
        case SMButtonVariant.primary:
          foregroundColor = SMColors.onAccent;
          break;
        case SMButtonVariant.secondary:
          foregroundColor = SMColors.primaryText;
          break;
        case SMButtonVariant.danger:
          foregroundColor = SMColors.error;
          break;
        default:
          foregroundColor = SMColors.primaryText;
      }
    }

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: isTSX ? 24 : SMDimensions.loadingSize,
        height: isTSX ? 24 : SMDimensions.loadingSize,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
          strokeWidth: isTSX ? 2.5 : SMDimensions.loadingStrokeWidth.toDouble(),
        ),
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isTSX ? 20 : SMDimensions.iconSize),
            SizedBox(width: isTSX ? 8 : SMSpacing.sm), // TSX gap-2 = 8px
          ],
          Text(
            text,
            style: (isTSX ? TSXTypography.button : SMTypography.button).copyWith(color: foregroundColor),
          ),
        ],
      );
    }

    final ButtonStyle style = _getButtonStyle(variant, isTSX);

    return ElevatedButton(
      onPressed: isActive ? onPressed : null,
      style: style.merge(
        ElevatedButton.styleFrom(
          minimumSize: Size(
            isTSX ? 0 : SMDimensions.touchTarget,
            isTSX ? 52 : SMDimensions.touchTarget, // TSX h-13 = 52px
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTSX ? 16 : SMSpacing.xl, // TSX px-4 = 16px
            vertical: isTSX ? 12 : SMSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTSX ? TSXRadius.button : SMRadius.medium),
          ),
        ),
      ),
      child: child,
    );
  }

  bool _isTSXVariant(SMButtonVariant v) {
    return v == SMButtonVariant.tsxPrimary ||
        v == SMButtonVariant.tsxSecondary ||
        v == SMButtonVariant.tsxDanger;
  }

  ButtonStyle _getButtonStyle(SMButtonVariant variant, bool isTSX) {
    if (isTSX) {
      switch (variant) {
        case SMButtonVariant.tsxPrimary:
          return ElevatedButton.styleFrom(
            backgroundColor: TSXColors.accent,
            foregroundColor: TSXColors.accentOn,
            disabledBackgroundColor: TSXColors.accent.withValues(alpha: 0.5),
            disabledForegroundColor: TSXColors.accentOn.withValues(alpha: 0.5),
            elevation: 0,
            shadowColor: TSXColors.accent.withValues(alpha: 0.1),
          );
        case SMButtonVariant.tsxSecondary:
          return ElevatedButton.styleFrom(
            backgroundColor: TSXColors.surface,
            foregroundColor: TSXColors.primaryText,
            disabledBackgroundColor: TSXColors.surfaceHover,
            disabledForegroundColor: TSXColors.mutedText,
            elevation: 0,
            side: BorderSide(color: TSXColors.surfaceBorder),
          );
        case SMButtonVariant.tsxDanger:
          return ElevatedButton.styleFrom(
            backgroundColor: TSXColors.rose.withValues(alpha: 0.15),
            foregroundColor: TSXColors.rose,
            disabledBackgroundColor: TSXColors.surfaceHover,
            disabledForegroundColor: TSXColors.mutedText,
            elevation: 0,
            side: BorderSide(color: TSXColors.rose.withValues(alpha: 0.3)),
          );
        default:
          return ElevatedButton.styleFrom();
      }
    } else {
      switch (variant) {
        case SMButtonVariant.primary:
          return ElevatedButton.styleFrom(
            backgroundColor: SMColors.soundmeshBlue,
            foregroundColor: SMColors.onAccent,
            disabledBackgroundColor: SMColors.disabledButtonFill,
            disabledForegroundColor: SMColors.disabledText,
          );
        case SMButtonVariant.secondary:
          return ElevatedButton.styleFrom(
            backgroundColor: SMColors.surfaceContainer,
            foregroundColor: SMColors.primaryText,
            disabledBackgroundColor: SMColors.disabledButtonFill,
            disabledForegroundColor: SMColors.disabledText,
          );
        case SMButtonVariant.danger:
          return ElevatedButton.styleFrom(
            backgroundColor: SMColors.surfaceHigh,
            foregroundColor: SMColors.error,
            disabledBackgroundColor: SMColors.disabledButtonFill,
            disabledForegroundColor: SMColors.disabledText,
          );
        default:
          return ElevatedButton.styleFrom();
      }
    }
  }
}
