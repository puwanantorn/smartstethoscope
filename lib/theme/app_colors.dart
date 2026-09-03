import 'package:flutter/material.dart';

/// Brand and status colors — these stay the same in both light and dark
/// mode (e.g. the BPM card is always blue, a "Normal" badge is always
/// green). Anything that should adapt to the theme (backgrounds, text,
/// borders) lives in `app_theme.dart` instead, via the `AppTheme` context
/// extension.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1E40AF);

  static const Color normal = Color(0xFF22C55E);
  static const Color murmur = Color(0xFFF97316);
  static const Color arrhythmia = Color(0xFFEF4444);

  /// Fixed dark-slate neutral for the RECORD button — always a "dark"
  /// action color regardless of theme. Deliberately lighter than the dark
  /// scaffold background (0xFF0F172A) so the button stays visible against
  /// it instead of blending in.
  static const Color recordButton = Color(0xFF334155);
}
