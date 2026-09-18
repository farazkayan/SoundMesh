import 'package:flutter/material.dart';
import '../../core/design_system/index.dart';

class SoundMeshIconWrapper extends StatelessWidget {
  const SoundMeshIconWrapper({
    super.key,
    required this.icon,
    this.onTap,
    this.semanticsLabel,
    this.color,
    this.backgroundColor,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final Color? color;
  final Color? backgroundColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isInteractive = enabled && onTap != null;
    final effectiveBackground = backgroundColor;
    final effectiveColor = color ??
        (effectiveBackground == SMColors.soundmeshBlue
            ? SMColors.onAccent
            : SMColors.primaryText);
    final disabledColor = SMColors.disabledIcon;

    final child = Semantics(
      label: semanticsLabel,
      button: isInteractive,
      enabled: enabled,
      child: Icon(
        icon,
        size: SMDimensions.iconSize,
        color: isInteractive ? effectiveColor : disabledColor,
      ),
    );

    if (!isInteractive) {
      if (effectiveBackground != null) {
        return Container(
          width: SMDimensions.touchTarget,
          height: SMDimensions.touchTarget,
          decoration: BoxDecoration(
            color: effectiveBackground,
            borderRadius: BorderRadius.circular(SMRadius.small),
          ),
          child: Center(child: child),
        );
      }
      return child;
    }

    return SizedBox.square(
      dimension: SMDimensions.touchTarget,
      child: Material(
        color: effectiveBackground ?? Colors.transparent,
        borderRadius: BorderRadius.circular(SMRadius.small),
        child: InkWell(
          borderRadius: BorderRadius.circular(SMRadius.small),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}