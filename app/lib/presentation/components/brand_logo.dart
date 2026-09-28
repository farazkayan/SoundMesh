import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'tsx_visual_tokens.dart';

/// Brand logo that switches between white/black variants based on theme brightness.
/// Supports TSX variant which uses graphic_eq icon instead of image.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size, this.tsx = false});

  const BrandLogo.tsx({super.key, required this.size}) : tsx = true;

  final double size;
  final bool tsx;

  @override
  Widget build(BuildContext context) {
    if (tsx) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: TSXColors.surface,
          borderRadius: BorderRadius.circular(TSXRadius.lg),
          border: Border.all(color: TSXColors.surfaceBorder),
          boxShadow: TSXShadows.lg,
        ),
        child: Center(
          child: Icon(
            Icons.graphic_eq,
            size: size * 0.55,
            color: TSXColors.accent,
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assetPath = isDark
        ? 'assets/logos/soundmesh-logo-white-trans.png'
        : 'assets/logos/soundmesh-logo-black-trans.png';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: SMColors.surfaceLow,
        borderRadius: BorderRadius.circular(SMRadius.large),
        boxShadow: SMElevation.elevatedSurface,
      ),
      child: Center(
        child: Image.asset(
          assetPath,
          width: size * 0.67,
          height: size * 0.67,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}