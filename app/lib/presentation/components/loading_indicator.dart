import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'tsx_visual_tokens.dart';

class SMLoadingIndicator extends StatelessWidget {
  const SMLoadingIndicator({super.key, this.size}) : tsx = false;

  const SMLoadingIndicator.tsx({super.key, this.size}) : tsx = true;

  final double? size;
  final bool tsx;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? (tsx ? 28.0 : SMDimensions.loadingSize.toDouble());
    return SizedBox.square(
      dimension: dimension,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(tsx ? TSXColors.accent : SMColors.loadingActive),
        backgroundColor: tsx ? TSXColors.surfaceBorder : SMColors.loadingBackground,
        strokeWidth: tsx ? 3 : SMDimensions.loadingStrokeWidth.toDouble(),
      ),
    );
  }
}