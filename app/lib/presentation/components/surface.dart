import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'tsx_visual_tokens.dart';

class SMCard extends StatelessWidget {
  const SMCard({
    super.key,
    required this.child,
    this.elevated = false,
    this.padding,
    this.borderRadius,
  });

  const SMCard.tsx({
    super.key,
    required this.child,
    this.elevated = false,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final bool elevated;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isTSX = runtimeType.toString().contains('tsx');

    if (isTSX) {
      return Container(
        decoration: BoxDecoration(
          color: TSXColors.surface,
          borderRadius: BorderRadius.circular(borderRadius ?? TSXRadius.card),
          border: Border.all(color: TSXColors.surfaceBorder),
          boxShadow: elevated ? TSXShadows.md : TSXShadows.sm,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.all(TSXSpacing.xl),
          child: child,
        ),
      );
    }

    // Original v3 design
    return Container(
      decoration: BoxDecoration(
        color: SMColors.surfaceLow,
        borderRadius: BorderRadius.circular(borderRadius ?? SMRadius.medium),
        border: Border.all(color: SMColors.outlineVariant.withValues(alpha: 0.2)),
        boxShadow: elevated ? SMElevation.card : SMElevation.surface,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(SMSpacing.xxl),
        child: child,
      ),
    );
  }
}
