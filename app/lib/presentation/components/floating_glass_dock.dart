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
/// Responsive: Adapts width based on available screen width, with min/max constraints.
class FloatingGlassDock extends StatelessWidget {
  const FloatingGlassDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabLabels = const ['Room', 'Devices'],
    this.tabIcons = const [Icons.surround_sound_outlined, Icons.tune],
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> tabLabels;
  final List<IconData> tabIcons;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive dock width
        // TSX: 220px fixed, but we adapt for narrow screens
        // Leave 16px margin on each side + safe area
        final double availableWidth = constraints.maxWidth;
        final double maxDockWidth = 220.0;
        final double minDockWidth = 180.0;
        final double dockWidth = (availableWidth - 32).clamp(minDockWidth, maxDockWidth);

        return Padding(
          padding: EdgeInsets.only(bottom: TSXSpacing.xl),
          child: Center(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: dockWidth,
                  height: 48,
                  decoration: BoxDecoration(
                    color: TSXColors.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(TSXRadius.pill),
                    border: Border.all(
                      color: TSXColors.surfaceBorder,
                      width: 1,
                    ),
                    boxShadow: TSXShadows.xl,
                  ),
                  // TSX uses justify-around with p-1 padding (4px)
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
                            // TSX: px-4 (16px) py-1.5 (6px)
                            // On narrow dock, reduce horizontal padding
                            padding: EdgeInsets.symmetric(
                              horizontal: dockWidth < 200 ? 12 : 16,
                              vertical: 6,
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
                                  size: 16, // w-4 h-4
                                  color: isActive ? TSXColors.accent : TSXColors.secondaryText,
                                ),
                                const SizedBox(width: 6), // gap-1.5
                                Text(
                                  tabLabels[index],
                                  style: TSXTypography.labelSmall.copyWith(
                                    fontSize: 12, // text-xs
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? TSXColors.accent : TSXColors.secondaryText,
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 6), // gap-1.5
                                  Container(
                                    width: 4, // w-1
                                    height: 4, // h-1
                                    decoration: BoxDecoration(
                                      color: TSXColors.accent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: TSXColors.accent.withValues(alpha: 0.6),
                                          blurRadius: 6,
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
      },
    );
  }
}