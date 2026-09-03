import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic surface/text/border tokens that adapt between light and dark
/// mode. Screens and widgets should read these via the [AppThemeX]
/// extension (`context.scaffoldBg`, `context.cardBg`, ...) instead of
/// hardcoding a color, so they automatically follow the active theme.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static const _AppSurfaceColors _lightScheme = _AppSurfaceColors(
    scaffoldBg: Color(0xFFF5F7FB),
    cardBg: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    cardBorder: Color(0xFFE2E8F0),
    cardShadow: Color(0x0F000000),
  );

  static const _AppSurfaceColors _darkScheme = _AppSurfaceColors(
    scaffoldBg: Color(0xFF0F172A),
    cardBg: Color(0xFF1E293B),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    cardBorder: Color(0xFF334155),
    cardShadow: Color(0x00000000),
  );

  static ThemeData _build(_AppSurfaceColors colors) {
    final Brightness brightness =
        colors == _darkScheme ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        surface: colors.cardBg,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outlineVariant: colors.cardBorder,
      ),
      scaffoldBackgroundColor: colors.scaffoldBg,
      cardColor: colors.cardBg,
      dividerColor: colors.cardBorder,
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }
}

@immutable
class _AppSurfaceColors extends ThemeExtension<_AppSurfaceColors> {
  const _AppSurfaceColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
    required this.cardShadow,
  });

  final Color scaffoldBg;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;
  final Color cardShadow;

  @override
  _AppSurfaceColors copyWith({
    Color? scaffoldBg,
    Color? cardBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? cardBorder,
    Color? cardShadow,
  }) {
    return _AppSurfaceColors(
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      cardBg: cardBg ?? this.cardBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  _AppSurfaceColors lerp(ThemeExtension<_AppSurfaceColors>? other, double t) {
    if (other is! _AppSurfaceColors) return this;
    return _AppSurfaceColors(
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension AppThemeX on BuildContext {
  _AppSurfaceColors get _surfaceColors =>
      Theme.of(this).extension<_AppSurfaceColors>()!;

  Color get scaffoldBg => _surfaceColors.scaffoldBg;
  Color get cardBg => _surfaceColors.cardBg;
  Color get textPrimary => _surfaceColors.textPrimary;
  Color get textSecondary => _surfaceColors.textSecondary;
  Color get cardBorder => _surfaceColors.cardBorder;

  /// A subtle drop shadow for cards — near-invisible in dark mode, since a
  /// black shadow reads as a smudge rather than depth on a dark surface.
  List<BoxShadow> get cardShadow => [
        BoxShadow(color: _surfaceColors.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
      ];
}
