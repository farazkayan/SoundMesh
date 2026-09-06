import 'package:flutter/material.dart';

class SoundMeshColors {
  static const Color background = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF181D23);
  static const Color elevatedSurface = Color(0xFF20262D);
  static const Color primaryText = Color(0xFFF5F7FA);
  static const Color secondaryText = Color(0xFFA7AFB9);
  static const Color mutedText = Color(0xFF6F7883);
  static const Color accent = Color(0xFF5B8CFF);
  static const Color success = Color(0xFF39D98A);
  static const Color warning = Color(0xFFFFB84D);
  static const Color error = Color(0xFFFF5C6C);
}

class SoundMeshTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SoundMeshColors.background,
      colorScheme: const ColorScheme.dark(
        surface: SoundMeshColors.surface,
        primary: SoundMeshColors.accent,
        secondary: SoundMeshColors.secondaryText,
        error: SoundMeshColors.error,
        onSurface: SoundMeshColors.primaryText,
        onPrimary: SoundMeshColors.primaryText,
        onSecondary: SoundMeshColors.primaryText,
        onError: SoundMeshColors.primaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SoundMeshColors.surface,
        foregroundColor: SoundMeshColors.primaryText,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: SoundMeshColors.elevatedSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: SoundMeshColors.primaryText,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: SoundMeshColors.primaryText,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: SoundMeshColors.primaryText,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: SoundMeshColors.primaryText,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: SoundMeshColors.secondaryText,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: SoundMeshColors.mutedText,
          fontSize: 12,
        ),
      ),
      iconTheme: const IconThemeData(
        color: SoundMeshColors.secondaryText,
      ),
      dividerTheme: const DividerThemeData(
        color: SoundMeshColors.elevatedSurface,
        thickness: 1,
      ),
    );
  }
}
