import 'package:flutter/material.dart';
import 'colors.dart';

/// Typography — designv3.md §5: Geist (all weights), bundled locally
/// (assets/fonts/, SIL OFL 1.1). Size scale from ui-ux.md §17 remains valid.
/// Negative tracking on headline roles follows the Calm Native v1 type spec
/// (headline letterSpacing -0.02em to -0.005em), converted to px per style.
class SMTypography {
  static const String fontFamily = 'Geist';

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 38 / 32,
    letterSpacing: -0.64,
  );

  static const TextStyle largeTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    letterSpacing: -0.42,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    letterSpacing: -0.22,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    letterSpacing: -0.09,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 22 / 16,
  );

  static const TextStyle bodyEmphasis = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 18 / 14,
  );

  static const TextStyle smallMetadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 18 / 14,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
  );

  static final TextStyle textOnAccent = body.copyWith(color: SMColors.onAccent);

  static final TextStyle buttonOnAccent = button.copyWith(color: SMColors.onAccent);

  static const TextStyle metadata = smallMetadata;
}