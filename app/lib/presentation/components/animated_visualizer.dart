import 'dart:math' show sin;

import 'package:flutter/material.dart';
import 'tsx_visual_tokens.dart';

/// Animated bar visualizer matching TSX HomeScreen visualizer.
/// 7 bars with sine-wave animation at 180ms interval.
class AnimatedVisualizer extends StatefulWidget {
  const AnimatedVisualizer({
    super.key,
    this.size = 56,
    this.active = true,
    this.color = TSXColors.accent,
    this.accentColor = TSXColors.accentHover,
    this.dimColor = TSXColors.mutedText,
  });

  final double size;
  final bool active;
  final Color color;
  final Color accentColor;
  final Color dimColor;

  @override
  State<AnimatedVisualizer> createState() => _AnimatedVisualizerState();
}

class _AnimatedVisualizerState extends State<AnimatedVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<double> _baseHeights;
  late final List<double> _currentHeights;

  @override
  void initState() {
    super.initState();
    _baseHeights = [16, 28, 44, 56, 48, 32, 20];
    _currentHeights = List.from(_baseHeights);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    )..addListener(_updateBars);

    if (widget.active) {
      _controller.repeat();
    }
  }

  void _updateBars() {
    if (!mounted) return;
    final time = DateTime.now().millisecondsSinceEpoch / 400;
    setState(() {
      for (int i = 0; i < 7; i++) {
        final delta = (sin(time + i * 0.8) * 10).floor();
        final height = (_baseHeights[i] + delta).clamp(12, 60).toDouble();
        _currentHeights[i] = height;
      }
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.repeat();
      } else {
        _controller.stop();
        // Reset to base heights
        setState(() {
          _currentHeights = List.from(_baseHeights);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = (widget.size / 7).floorToDouble() * 0.35;
    final maxBarHeight = widget.size * 0.7;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final normalizedHeight = (_currentHeights[i] / 60) * maxBarHeight;
            final isCenter = i == 3;

            return AnimatedContainer(
              duration: TSXAnimation.micro,
              curve: TSXAnimation.standard,
              width: barWidth,
              height: normalizedHeight,
              margin: EdgeInsets.symmetric(horizontal: barWidth * 0.15),
              decoration: BoxDecoration(
                color: isCenter
                    ? widget.accentColor
                    : (i == 0 || i == 6
                        ? widget.dimColor
                        : (i == 1 || i == 5 ? widget.dimColor : widget.color)),
                borderRadius: BorderRadius.circular(barWidth / 2),
                boxShadow: isCenter
                    ? [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Simplified visualizer for dashboard (active when sharing audio)
class DashboardVisualizer extends StatefulWidget {
  const DashboardVisualizer({
    super.key,
    this.active = false,
  });

  final bool active;

  @override
  State<DashboardVisualizer> createState() => _DashboardVisualizerState();
}

class _DashboardVisualizerState extends State<DashboardVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _barHeights = [8, 16, 26, 36, 28, 18, 10];

    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    )..addListener(_updateBars);
  }

  void _updateBars() {
    if (!mounted || !widget.active) return;
    setState(() {
      _barHeights = [
        (8 + (DateTime.now().millisecondsSinceEpoch % 14)).toDouble(),
        (14 + (DateTime.now().millisecondsSinceEpoch * 2 % 20)).toDouble(),
        (22 + (DateTime.now().millisecondsSinceEpoch * 3 % 24)).toDouble(),
        (30 + (DateTime.now().millisecondsSinceEpoch * 4 % 26)).toDouble(),
        (20 + (DateTime.now().millisecondsSinceEpoch * 5 % 22)).toDouble(),
        (12 + (DateTime.now().millisecondsSinceEpoch * 6 % 18)).toDouble(),
        (8 + (DateTime.now().millisecondsSinceEpoch * 7 % 12)).toDouble(),
      ];
    });
  }

  @override
  void didUpdateWidget(covariant DashboardVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat();
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final isCenter = i == 3;
          return AnimatedContainer(
            duration: TSXAnimation.micro,
            curve: TSXAnimation.standard,
            width: 4,
            height: _barHeights[i],
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isCenter
                  ? TSXColors.accentHover
                  : TSXColors.accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: isCenter
                  ? [
                      BoxShadow(
                        color: TSXColors.accent.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}