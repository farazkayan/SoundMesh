import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundmesh/core/router/app_router.dart';
import 'package:soundmesh/presentation/components/index.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _timer;
  List<double> _barHeights = [12.0, 19.0, 42.0, 60.0, 57.0, 39.0, 21.0];

  @override
  void initState() {
    super.initState();
    const baseHeights = [16.0, 28.0, 44.0, 56.0, 48.0, 32.0, 20.0];

    // Recreates the TSX sine-wave animation running every 180ms
    _timer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _barHeights = List.generate(7, (index) {
          final delta = (math.sin(now / 400.0 + index * 0.8) * 10).floor();
          return (baseHeights[index] + delta).clamp(12.0, 60.0);
        });
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071012),
      body: SafeArea(
        child: Column(
          children: [
            // Top Sticky Header
            _buildHeader(context),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),

                        // Radar Circle & Animated Audio Visualizer
                        _buildRadarVisualizer(),

                        const SizedBox(height: 20),

                        // Title & Tagline
                        const Text(
                          'SoundMesh',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Plus_Jakarta_Sans',
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: Color(0xFFEDF7F6),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Make your phones one speaker.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Plus_Jakarta_Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF87999A),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Action Buttons Container
                        _buildActionButtons(context),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xCC061013), // bg-[#061013]/80 backdrop feel
        border: Border(
          bottom: BorderSide(
            color: Color(0x0AFFFFFF), // border-white/[0.04]
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, AppRouter.support),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                height: 36, // h-9
                padding: const EdgeInsets.symmetric(horizontal: 14), // px-3.5
                decoration: BoxDecoration(
                  color: const Color(0xFF0E181B),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF172327)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: Color(0xFFEF4444), // #ef4444
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Support',
                      style: TextStyle(
                        fontFamily: 'Plus_Jakarta_Sans',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFEDF7F6),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarVisualizer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // TSX: w-56 h-56 (224px) on mobile, w-64 h-64 (256px) on sm
        // Responsive: scale down on narrow screens, max 256px
        final double maxSize = 256.0;
        final double minSize = 180.0;
        final double availableWidth = constraints.maxWidth - 40; // account for padding
        final double radarSize = availableWidth.clamp(minSize, maxSize);
        final double visualizerCardWidth = radarSize * (112 / 224); // w-28 proportion
        final double visualizerCardHeight = radarSize * (80 / 224);  // h-20 proportion
        final double barWidth = radarSize * (4 / 224);
        final double centerBarWidth = radarSize * (6 / 224);
        final double barGap = radarSize * (4 / 224);
        final double cardPadding = radarSize * (12 / 224);
        final double cardBorderRadius = radarSize * (16 / 224);

        return SizedBox(
          width: radarSize,
          height: radarSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radar Vector Background
              CustomPaint(
                size: Size(radarSize, radarSize),
                painter: _RadarPainter(),
              ),

              // Central Visualizer Card
              Container(
                width: visualizerCardWidth,
                height: visualizerCardHeight,
                padding: EdgeInsets.symmetric(horizontal: cardPadding),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E181B),
                  borderRadius: BorderRadius.circular(cardBorderRadius),
                  border: Border.all(color: const Color(0xFF172327)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildBar(0, width: barWidth, color: const Color(0xFF3D4948)),
                    SizedBox(width: barGap),
                    _buildBar(1, width: barWidth, color: const Color(0xFF87999A)),
                    SizedBox(width: barGap),
                    _buildBar(2, width: barWidth, color: const Color(0xFF5ED6D0)),
                    SizedBox(width: barGap),
                    // Center glowing bar
                    _buildBar(
                      3,
                      width: centerBarWidth,
                      color: const Color(0xFF7DF3EC),
                      glow: true,
                    ),
                    SizedBox(width: barGap),
                    _buildBar(4, width: barWidth, color: const Color(0xFF5ED6D0)),
                    SizedBox(width: barGap),
                    _buildBar(5, width: barWidth, color: const Color(0xFF87999A)),
                    SizedBox(width: barGap),
                    _buildBar(6, width: barWidth, color: const Color(0xFF3D4948)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(int index, {required double width, required Color color, bool glow = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: width,
      height: _barHeights[index],
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(100),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0xFF5ED6D0).withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Create Room Button - full width like TSX (w-full h-13)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: SMButton(
            text: 'Create Room',
            icon: Icons.add_circle,
            variant: SMButtonVariant.tsxPrimary,
            onPressed: () => Navigator.pushNamed(context, AppRouter.createRoom),
          ),
        ),
        const SizedBox(height: 12),
        // Join Room Button - full width like TSX (w-full h-13)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: SMButton(
            text: 'Join Room',
            icon: Icons.sensors,
            variant: SMButtonVariant.tsxSecondary,
            onPressed: () => Navigator.pushNamed(context, AppRouter.joinRoom),
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer Circle (r = 100/256 of size)
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF5ED6D0).withValues(alpha: 0.15);
    canvas.drawCircle(center, size.width * (100 / 256), outerPaint);

    // Inner Circle (dashed, r = 64/256 of size)
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF5ED6D0).withValues(alpha: 0.08);
    _drawDashedCircle(canvas, center, size.width * (64 / 256), innerPaint);

    // Crosshair Lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF5ED6D0).withValues(alpha: 0.12);

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, size.height * (16 / 256)),
      Offset(center.dx, size.height * (240 / 256)),
      linePaint,
    );

    // Horizontal line
    canvas.drawLine(
      Offset(size.width * (16 / 256), center.dy),
      Offset(size.width * (240 / 256), center.dy),
      linePaint,
    );
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashLength = 4.0;
    const gapLength = 4.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashLength + gapLength) / radius);
      final sweepAngle = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}