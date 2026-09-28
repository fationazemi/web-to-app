import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Colors shared by both themes. The palette mirrors the design: warm paper
/// tones, near-black ink and a dusty blue accent.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF1B1B19);
  static const paper = Color(0xFFF5F3EE);
  static const paperDark = Color(0xFF111111);
  static const card = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1C1C1C);
  static const accent = Color(0xFF8A9BC4);
  static const accentDeep = Color(0xFF6F82B5);
  static const accentLight = Color(0xFFB9C4E3);
  static const accentSoft = Color(0xFFE8EBF7);
  static const orange = Color(0xFFF08A24);

  /// The swatches shown under the canvas.
  static const palette = <Color>[
    Color(0xFF1B1B19),
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

/// Handwritten style used for accents (canvas title, hints, notes).
TextStyle handStyle({
  double size = 22,
  bool bold = true,
  Color? color,
  double height = 1.0,
}) {
  return TextStyle(
    fontFamily: 'Caveat',
    fontSize: size,
    fontVariations: [FontVariation('wght', bold ? 700 : 400)],
    color: color,
    height: height,
  );
}

/// Soft drop shadow used on cards and floating controls.
List<BoxShadow> softShadow(BuildContext context, {double blur = 18, double y = 6, double alpha = 0.06}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? alpha * 4 : alpha),
      blurRadius: blur,
      offset: Offset(0, y),
    ),
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
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: 'Inter');
  final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    cardColor: dark ? AppColors.cardDark : AppColors.card,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
    ),
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      labelSmall: text.labelSmall?.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.12),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.08),
      trackHeight: 3,
    ),
    dividerColor: scheme.onSurface.withValues(alpha: dark ? 0.12 : 0.07),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.primary,
      contentTextStyle: TextStyle(fontFamily: 'Inter', color: scheme.onPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? AppColors.cardDark : AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? AppColors.cardDark : AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? AppColors.cardDark : AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
      shadowColor: Colors.black26,
    ),
  );
}
