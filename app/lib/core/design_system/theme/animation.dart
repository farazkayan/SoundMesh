import 'package:flutter/material.dart';

class SMAnimation {
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration major = Duration(milliseconds: 300);

  // Stub delays for development/testing - not production animations
  static const Duration stubShort = Duration(milliseconds: 200);
  static const Duration stubMedium = Duration(milliseconds: 500);
  static const Duration stubLong = Duration(milliseconds: 800);

  static const Curve standard = Curves.fastOutSlowIn;
}