import 'package:flutter/material.dart';
import 'tsx_visual_tokens.dart';

/// Radial gradient backdrop matching TSX CSS:
/// background-image: radial-gradient(ellipse 60% 35% at 50% 15%, rgba(94,214,208,0.06), transparent 70%)
class RadialGradientBackdrop extends StatelessWidget {
  const RadialGradientBackdrop({super.key, this.opacity = 1.0});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadialGradientPainter(opacity: opacity),
      size: Size.infinite,
    );
  }
}

class _RadialGradientPainter extends CustomPainter {
  _RadialGradientPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: const Alignment(0, -0.7), // 50% 15%
      radius: 0.85,
      colors: [
        TSXColors.radialGlow.withValues(alpha: 0.06 * opacity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.7],
      focal: const Alignment(0, -0.7),
      focalRadius: 0,
    ).createShader(rect);

    canvas.drawRect(rect, Paint()..shader = gradient);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _RadialGradientPainter && oldDelegate.opacity != opacity;
  }
}

/// Alternative simpler backdrop using Container decoration (less performant but simpler)
class RadialGradientBackdropSimple extends StatelessWidget {
  const RadialGradientBackdropSimple({super.key, this.opacity = 1.0});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.7),
          radius: 0.85,
          colors: [
            TSXColors.radialGlow.withValues(alpha: 0.06 * opacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}