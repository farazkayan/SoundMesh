import 'package:flutter/material.dart';
import '../../core/design_system/index.dart';

class SoundMeshSurface extends StatelessWidget {
  const SoundMeshSurface({
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
    // Cards use the surface ladder's Low step (designv3.md §4), matching the
    // Stitch v1 export's card fills. The elevated flag adds the export's
    // card shadow (shadow-sm). The subtle outline-variant border mirrors the
    // export's border-outline-variant/20 card treatment.
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