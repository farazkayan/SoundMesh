import 'package:flutter/material.dart';

/// Color tokens — designv3.md §4 (Calm Native v1, dark mode only).
///
/// Canonical source: DOCS/stitch_soundmesh/stitch_soundmesh_ui/designv3.md.
/// The v2 palette (warm undertone, #b2c5ff secondary accent, old ui-ux.md
/// hexes) is rejected and must not be reintroduced.
class SMColors {
  // Backgrounds & surfaces.
  // Surface (base) equals the background by design: separation comes from
  // the surface ladder below, not a background/surface split.
  static const Color background = Color(0xFF131314);
  static const Color surface = Color(0xFF131314);

  // Surface ladder (elevation/layering).
  static const Color surfaceLowest = Color(0xFF0E0E0F);
  static const Color surfaceLow = Color(0xFF1B1B1C);
  static const Color surfaceContainer = Color(0xFF201F20);
  static const Color surfaceHigh = Color(0xFF2A2A2B);
  static const Color surfaceHighest = Color(0xFF353436);

  // Text.
  static const Color primaryText = Color(0xFFE5E2E3);
  static const Color secondaryText = Color(0xFFC3C6D6);
  // Muted/tertiary text — derived token (see designv3.md §9 Open Items).
  // Taken from the raw export's --dark-text-secondary (#8E8E98); restricted
  // to captions, timestamps, and large-scale secondary labels. It must not
  // be used for normal-sized body text or information-critical content.
  // Contrast verified in test/design_tokens_test.dart.
  static const Color mutedText = Color(0xFF8E8E98);

  // Accent — single blue only (designv3.md §4). The export's lighter
  // #b2c5ff primary token is rejected; do not reintroduce it.
  static const Color soundmeshBlue = Color(0xFF5B8CFF);

  // On-accent text/icons: dark navy per designv3.md §4. Pairing verified
  // in test/design_tokens_test.dart (passes AA large-text, not AA normal).
  static const Color onAccent = Color(0xFF002C72);

  // Semantic colors (designv3.md §4).
  static const Color warning = Color(0xFFFFB874);
  static const Color error = Color(0xFFFFB4AB);
  // Success: designv3.md §4 defines no success color and the raw Stitch
  // exports contain no success green. Per designv3's "wherever they
  // conflict" clause, the documented ui-ux.md §10 Success value remains
  // valid and is re-verified against #131314 in the contrast tests.
  // Pending a designv3 successor value — do not silently replace it.
  static const Color success = Color(0xFF39D98A);

  // Border/outline (designv3.md §4).
  static const Color outline = Color(0xFF8D909F);
  static const Color outlineVariant = Color(0xFF434653);

  // Derived disabled states (alpha blends of listed tokens).
  static final Color disabledText = primaryText.withValues(alpha: 0.38);
  static final Color disabledIcon = secondaryText.withValues(alpha: 0.38);
  static final Color disabledContainer = Color.alphaBlend(
    surfaceContainer.withValues(alpha: 0.12),
    background,
  );
  // Disabled buttons recede into the surface ladder instead of reading as
  // an enabled neutral fill.
  static const Color disabledButtonFill = surfaceHigh;

  static const Color divider = outlineVariant;

  static final Color scrim = Colors.black.withValues(alpha: 0.6);

  static const Color loadingActive = soundmeshBlue;
  static const Color loadingBackground = Colors.transparent;

  static const Color transparent = Colors.transparent;

  // shadow-black/40 — designv3.md §6 accepted shadow treatment.
  static const Color elevatedShadowColor = Color.fromRGBO(0, 0, 0, 0.4);
}