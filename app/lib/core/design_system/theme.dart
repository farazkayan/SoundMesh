import 'package:flutter/material.dart';

import 'animation.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

export 'animation.dart';
export 'colors.dart';
export 'spacing.dart';
export 'typography.dart';

class SMTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SMColors.background,
    colorScheme: ColorScheme.dark(
      surface: SMColors.surface,
      onSurface: SMColors.primaryText,
      primary: SMColors.soundmeshBlue,
      onPrimary: SMColors.onAccent,
      secondary: SMColors.soundmeshBlue,
      onSecondary: SMColors.onAccent,
      error: SMColors.error,
      // Derived on-color: the dark neutral background on the light error
      // fill (contrast verified in test/design_tokens_test.dart).
      onError: SMColors.background,
    ),
    dividerColor: SMColors.divider,
    dividerTheme: DividerThemeData(
      color: SMColors.divider,
      thickness: 1,
      space: 1,
    ),
    textTheme: const TextTheme(
      displayLarge: SMTypography.display,
      headlineLarge: SMTypography.largeTitle,
      titleLarge: SMTypography.title,
      titleMedium: SMTypography.title,
      titleSmall: SMTypography.heading,
      bodyLarge: SMTypography.bodyEmphasis,
      bodyMedium: SMTypography.body,
      bodySmall: SMTypography.caption,
      labelLarge: SMTypography.label,
      labelMedium: SMTypography.metadata,
      labelSmall: SMTypography.metadata,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SMColors.soundmeshBlue,
        foregroundColor: SMColors.onAccent,
        disabledBackgroundColor: SMColors.disabledButtonFill,
        disabledForegroundColor: SMColors.disabledText,
        minimumSize: Size(SMDimensions.touchTarget, SMDimensions.touchTarget),
        padding: EdgeInsets.symmetric(
          horizontal: SMSpacing.xl,
          vertical: SMSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SMRadius.medium),
        ),
        animationDuration: SMAnimation.micro,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SMColors.soundmeshBlue,
        side: BorderSide(color: SMColors.soundmeshBlue),
        disabledForegroundColor: SMColors.disabledText,
        minimumSize: Size(SMDimensions.touchTarget, SMDimensions.touchTarget),
        padding: EdgeInsets.symmetric(
          horizontal: SMSpacing.xl,
          vertical: SMSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SMRadius.medium),
        ),
        animationDuration: SMAnimation.micro,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SMColors.soundmeshBlue,
        disabledForegroundColor: SMColors.disabledText,
        minimumSize: Size(SMDimensions.touchTarget, SMDimensions.touchTarget),
        padding: EdgeInsets.symmetric(
          horizontal: SMSpacing.xl,
          vertical: SMSpacing.md,
        ),
        animationDuration: SMAnimation.micro,
      ),
    ),
    cardTheme: CardThemeData(
      color: SMColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SMRadius.medium),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SMColors.surfaceHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SMRadius.large),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: SMColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SMRadius.large),
        ),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SMColors.surfaceLow,
      contentPadding: EdgeInsets.symmetric(
        horizontal: SMSpacing.lg,
        vertical: SMSpacing.md,
      ),
      hintStyle: SMTypography.caption.copyWith(color: SMColors.mutedText),
      labelStyle: SMTypography.body.copyWith(color: SMColors.secondaryText),
      errorStyle: SMTypography.caption.copyWith(color: SMColors.error),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: SMColors.outlineVariant),
        borderRadius: BorderRadius.circular(SMRadius.medium),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: SMColors.soundmeshBlue),
        borderRadius: BorderRadius.circular(SMRadius.medium),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: SMColors.error),
        borderRadius: BorderRadius.circular(SMRadius.medium),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: SMColors.error),
        borderRadius: BorderRadius.circular(SMRadius.medium),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: SMColors.disabledIcon),
        borderRadius: BorderRadius.circular(SMRadius.medium),
      ),
    ),
    // Pill-shaped bottom nav items (rounded-full) — designv3.md §6.
    // The blur/frosted treatment lives in room_shell.dart (bottom nav only).
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: SMColors.surface.withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      indicatorColor: SMColors.soundmeshBlue.withValues(alpha: 0.2),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SMRadius.full),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected ? SMColors.soundmeshBlue : SMColors.secondaryText,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return SMTypography.smallMetadata.copyWith(
          fontWeight: FontWeight.w600,
          color: selected ? SMColors.soundmeshBlue : SMColors.secondaryText,
        );
      }),
    ),
  );
}