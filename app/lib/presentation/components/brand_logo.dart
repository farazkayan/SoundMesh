import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';

/// Brand logo that switches between white/black variants based on theme brightness.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
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
          width: size * 0.67, // ~64px at 96px container
          height: size * 0.67,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}