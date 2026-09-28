import 'package:flutter/material.dart';

/// Colors shared by both themes. The palette mirrors the design: warm paper
/// tones, near-black ink and a dusty blue accent.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF1C1C1A);
  static const paper = Color(0xFFF4F2ED);
  static const paperDark = Color(0xFF121212);
  static const card = Color(0xFFFAF9F6);
  static const cardDark = Color(0xFF1E1E1E);
  static const accent = Color(0xFF8A9BC4);
  static const accentSoft = Color(0xFFE6E9F5);
  static const orange = Color(0xFFF08A24);

  /// The swatches shown under the canvas.
  static const palette = <Color>[
    Color(0xFF1C1C1A),
    Color(0xFF8E8E8E),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFEC407A),
  ];
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
    surface: dark ? AppColors.paperDark : AppColors.paper,
    primary: dark ? Colors.white : AppColors.ink,
    onPrimary: dark ? AppColors.ink : Colors.white,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    cardColor: dark ? AppColors.cardDark : AppColors.card,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.15),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.1),
      trackHeight: 3,
    ),
    dividerColor: scheme.onSurface.withValues(alpha: 0.08),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.primary,
      contentTextStyle: TextStyle(color: scheme.onPrimary),
    ),
  );
}
