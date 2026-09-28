import 'package:flutter/material.dart';
import 'tsx_visual_tokens.dart';
import 'dart:ui' show ImageFilter;

/// Floating glass dock matching TSX HostRoomDashboard bottom navigation.
/// Pill-shaped with backdrop blur, two tabs: Room and Devices.
/// TSX: w-[220px] h-[48px] p-1 (4px), rounded-full, backdrop-blur-xl
/// Buttons: gap-1.5 (6px) px-4 (16px) py-1.5 (6px) rounded-full
/// Icons: w-4 h-4 (16px), Text: text-xs (12px) font-semibold
/// Active indicator: w-1 h-1 (4px) dot with glow
///
/// Responsive: Adapts width/height based on screen size.
/// On tablets: wider, taller, larger icons/text.
class FloatingGlassDock extends StatelessWidget {
  const FloatingGlassDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabLabels = const ['Room', 'Devices'],
    this.tabIcons = const [Icons.surround_sound_outlined, Icons.tune],
    this.isTablet = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> tabLabels;
  final List<IconData> tabIcons;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    // Tablet sizing
    final double dockWidth = isTablet ? 320.0 : 220.0;
    final double dockHeight = isTablet ? 56.0 : 48.0;
    final double iconSize = isTablet ? 20.0 : 16.0;
    final double fontSize = isTablet ? 13.0 : 12.0;
    final double hPadding = isTablet ? 20.0 : 16.0;
    final double vPadding = isTablet ? 8.0 : 6.0;
    final double indicatorSize = isTablet ? 5.0 : 4.0;
    final double gap = isTablet ? 8.0 : 6.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isTablet ? TSXSpacing.xxl : TSXSpacing.xl),
      child: Center(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: dockWidth,
              height: dockHeight,
              decoration: BoxDecoration(
                color: TSXColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(TSXRadius.pill),
                border: Border.all(
                  color: TSXColors.surfaceBorder,
                  width: 1,
                ),
                boxShadow: TSXShadows.xl,
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(2, (index) {
                  final isActive = index == currentIndex;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(index),
                      borderRadius: BorderRadius.circular(TSXRadius.pill),
                      child: AnimatedContainer(
                        duration: TSXAnimation.normal,
                        curve: TSXAnimation.standard,
                        padding: EdgeInsets.symmetric(
                          horizontal: hPadding,
                          vertical: vPadding,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? TSXColors.surfaceBorder : Colors.transparent,
                          borderRadius: BorderRadius.circular(TSXRadius.pill),
                          boxShadow: isActive ? TSXShadows.sm : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tabIcons[index],
                              size: iconSize,
                              color: isActive ? TSXColors.accent : TSXColors.secondaryText,
                            ),
                            SizedBox(width: gap),
                            Text(
                              tabLabels[index],
                              style: TSXTypography.labelSmall.copyWith(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                                color: isActive ? TSXColors.accent : TSXColors.secondaryText,
                              ),
                            ),
                            if (isActive) ...[
                              SizedBox(width: gap),
                              Container(
                                width: indicatorSize,
                                height: indicatorSize,
                                decoration: BoxDecoration(
                                  color: TSXColors.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: TSXColors.accent.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}