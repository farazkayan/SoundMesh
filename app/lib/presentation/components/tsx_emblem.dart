import 'package:flutter/material.dart';
import 'tsx_visual_tokens.dart';

/// TSX Emblem component matching HomeScreen and other screens.
/// Circular container with graphic_eq icon, replaces BrandLogo.
class TSXEmblem extends StatelessWidget {
  const TSXEmblem({
    super.key,
    this.size = 52,
    this.iconSize = 28,
    this.active = false,
    this.pulse = false,
  });

  final double size;
  final double iconSize;
  final bool active;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TSXAnimation.normal,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TSXColors.surface,
        borderRadius: BorderRadius.circular(TSXRadius.lg),
        border: Border.all(
          color: active ? TSXColors.accent.withValues(alpha: 0.5) : TSXColors.surfaceBorder,
          width: active ? 2 : 1,
        ),
        boxShadow: [
          if (active) ...TSXShadows.md,
          if (!active) ...TSXShadows.lg,
        ],
      ),
      child: Center(
        child: Icon(
          Icons.graphic_eq,
          size: iconSize,
          color: active ? TSXColors.accentHover : TSXColors.accent,
        ),
      ),
    );
  }
}

/// Pulsing emblem for active states (matching TSX radio_button_checked pulse)
class TSXPulsingEmblem extends StatefulWidget {
  const TSXPulsingEmblem({
    super.key,
    this.size = 52,
    this.iconSize = 28,
    this.color = TSXColors.accent,
  });

  final double size;
  final double iconSize;
  final Color color;

  @override
  State<TSXPulsingEmblem> createState() => _TSXPulsingEmblemState();
}

class _TSXPulsingEmblemState extends State<TSXPulsingEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: TSXColors.surface,
            borderRadius: BorderRadius.circular(TSXRadius.lg),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.15 * _controller.value),
                blurRadius: 20 * _controller.value,
                spreadRadius: -4 * _controller.value,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.radio_button_checked,
              size: widget.iconSize,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}