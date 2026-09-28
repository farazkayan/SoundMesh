import 'package:flutter/material.dart';

/// TSX Visual Tokens — exact color/typography/spacing/radius from TSX redesign.
/// Used ONLY by migrated screens/components. Does not replace global SMColors/SMTypography.
class TSXColors {
  // Backgrounds & surfaces
  static const Color background = Color(0xFF071012);
  static const Color surface = Color(0xFF0E181B);
  static const Color surfaceBorder = Color(0xFF172327);
  static const Color surfaceHover = Color(0xFF142024);
  static const Color surfacePressed = Color(0xFF0E181B);

  // Text
  static const Color primaryText = Color(0xFFEDF7F6);
  static const Color secondaryText = Color(0xFF87999A);
  static const Color mutedText = Color(0xFF6F7883);

  // Accents
  static const Color accent = Color(0xFF5ED6D0);
  static const Color accentHover = Color(0xFF7DF3EC);
  static const Color accentBright = Color(0xFF7DF3EC); // alias for accentHover
  static const Color accentDim = Color(0xFF5ED6D0);
  static const Color accentOn = Color(0xFF005B58);

  // Semantic
  static const Color success = Color(0xFF39D98A);
  static const Color warning = Color(0xFFFFB84D);
  static const Color error = Color(0xFFFF5C6C);
  static const Color rose = Color(0xFFF43F5E);

  // Gradients / overlays
  static const Color radialGlow = Color(0xFF5ED6D0);
  static const Color overlayScrim = Color(0xCC000000); // 80% black

  // Shadows
  static const Color shadowSm = Color(0x0D000000);
  static const Color shadowLg = Color(0x1A000000);
  static const Color shadowXl = Color(0x66000000);
}

class TSXTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 38 / 32,
    letterSpacing: -0.64,
    color: TSXColors.primaryText,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    letterSpacing: -0.42,
    color: TSXColors.primaryText,
  );

  static const TextStyle displayCode = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 44 / 36,
    letterSpacing: 8,
    color: TSXColors.primaryText,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    letterSpacing: -0.22,
    color: TSXColors.primaryText,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    letterSpacing: -0.09,
    color: TSXColors.primaryText,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    letterSpacing: -0.09,
    color: TSXColors.primaryText,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: TSXColors.primaryText,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: TSXColors.primaryText,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    color: TSXColors.secondaryText,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: TSXColors.secondaryText,
  );

  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.5,
    color: TSXColors.secondaryText,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
    letterSpacing: 0.5,
    color: TSXColors.primaryText,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    letterSpacing: 0.5,
    color: TSXColors.primaryText,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.8,
    color: TSXColors.secondaryText,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
    letterSpacing: 0.5,
    color: TSXColors.accentOn,
  );

  static const TextStyle buttonSecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
    letterSpacing: 0.5,
    color: TSXColors.primaryText,
  );
}

class TSXSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 48;

  static const double screenPadding = xl;
  static const double cardPadding = lg;
  static const double sectionGap = xxl;
  static const double elementGap = md;
}

class TSXRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;

  static const double button = md;
  static const double input = lg;
  static const double card = lg;
  static const double modal = xl;
  static const double pill = full;
  static const double emblem = md;
}

class TSXAnimation {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration major = Duration(milliseconds: 300);
  static const Curve standard = Curves.fastOutSlowIn;
  static const Curve spring = Curves.elasticOut;
}

class TSXShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: TSXColors.shadowSm,
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: TSXColors.shadowLg,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: TSXColors.shadowXl,
      blurRadius: 25,
      offset: Offset(0, 12),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: TSXColors.shadowXl,
      blurRadius: 50,
      offset: Offset(0, 25),
      spreadRadius: -12,
    ),
  ];
}