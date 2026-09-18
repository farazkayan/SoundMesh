import 'package:flutter/material.dart';
import 'colors.dart';

/// Elevation/shadow — designv3.md §6: the surface ladder (colors.dart) is
/// the primary depth cue. Shadow usage follows the Stitch v1 export exactly:
/// no invented treatments beyond what the export shows.
class SMElevation {
  // Base surfaces rely on the surface ladder — no shadow.
  static const List<BoxShadow> surface = <BoxShadow>[];

  // Export cards (shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05)).
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.05),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  // Strongly elevated elements (shadow-2xl shadow-black/40, as cited in
  // designv3.md §6 — e.g. the home brand container in the export).
  static const List<BoxShadow> elevatedSurface = <BoxShadow>[
    BoxShadow(
      color: SMColors.elevatedShadowColor,
      blurRadius: 50,
      offset: Offset(0, 25),
      spreadRadius: -12,
    ),
  ];
}