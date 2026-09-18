import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';

class SMLoadingIndicator extends StatelessWidget {
  const SMLoadingIndicator({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? SMDimensions.loadingSize.toDouble();
    return SizedBox.square(
      dimension: dimension,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(SMColors.loadingActive),
        backgroundColor: SMColors.loadingBackground,
        strokeWidth: SMDimensions.loadingStrokeWidth.toDouble(),
      ),
    );
  }
}