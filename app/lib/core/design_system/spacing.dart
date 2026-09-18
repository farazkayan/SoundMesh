class SMSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  // Aliases for existing usage
  static const double spacing4 = xs;
  static const double spacing8 = sm;
  static const double spacing12 = md;
  static const double spacing16 = lg;
  static const double spacing20 = xl;
  static const double spacing24 = xxl;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;
  static const double spacing64 = 64;
}

class SMDimensions {
  static const double touchTarget = 44;
  static const double iconSize = SMSpacing.xxl;
  static const double loadingSize = SMSpacing.xxl;
  static const double loadingStrokeWidth = 3;
  static const double emptyIconSize = SMSpacing.spacing48;
}

/// Corner radii — designv3.md §6 (Stitch v1, canonical).
class SMRadius {
  static const double xs = 4; // 'sm'
  static const double small = 8; // 'DEFAULT'
  static const double medium = 12; // 'md'
  static const double large = 16; // 'lg'
  static const double xl = 24; // 'xl'
  static const double full = 9999; // 'full' (pill)
}