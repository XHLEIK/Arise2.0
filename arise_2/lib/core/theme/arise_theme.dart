import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'arise_colors.dart';

/// The master theme for A.R.I.S.E. 2.0 — a dark, cinematic experience
/// following the "Digital Curator" design language.
class AriseTheme {
  AriseTheme._();

  // ── Typography ────────────────────────────────────────────────────────

  static TextStyle _spaceGrotesk({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    Color color = AriseColors.onSurface,
    double height = 1.4,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
    );
  }

  static TextStyle _inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    double letterSpacing = 0,
    Color color = AriseColors.onSurface,
    double height = 1.5,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
    );
  }

  static final TextTheme _textTheme = TextTheme(
    // ── Display (Space Grotesk) ──
    displayLarge: _spaceGrotesk(
      fontSize: 57,
      fontWeight: FontWeight.w700,
      letterSpacing: -2.28, // -0.04em
      height: 1.12,
    ),
    displayMedium: _spaceGrotesk(
      fontSize: 45,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.8,
      height: 1.16,
    ),
    displaySmall: _spaceGrotesk(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.44,
      height: 1.22,
    ),

    // ── Headlines (Space Grotesk) ──
    headlineLarge: _spaceGrotesk(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.64,
      height: 1.25,
    ),
    headlineMedium: _spaceGrotesk(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.28,
      height: 1.29,
    ),
    headlineSmall: _spaceGrotesk(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.33,
    ),

    // ── Titles (Inter) ──
    titleLarge: _inter(fontSize: 22, fontWeight: FontWeight.w600, height: 1.27),
    titleMedium: _inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.5,
    ),
    titleSmall: _inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.43,
    ),

    // ── Body (Inter) ──
    bodyLarge: _inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
      height: 1.5,
    ),
    bodyMedium: _inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      height: 1.5,
    ),
    bodySmall: _inter(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      height: 1.5,
    ),

    // ── Labels (Space Grotesk – HUD style) ──
    labelLarge: _spaceGrotesk(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.4, // 0.1em
      height: 1.43,
    ),
    labelMedium: _spaceGrotesk(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
      height: 1.33,
    ),
    labelSmall: _spaceGrotesk(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.1,
      height: 1.45,
    ),
  );

  // ── Color Scheme ──────────────────────────────────────────────────────

  static final ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AriseColors.primary,
    onPrimary: AriseColors.onPrimary,
    primaryContainer: AriseColors.primaryContainer,
    onPrimaryContainer: AriseColors.onPrimaryContainer,
    secondary: AriseColors.secondary,
    onSecondary: AriseColors.onSecondary,
    secondaryContainer: AriseColors.secondaryContainer,
    onSecondaryContainer: AriseColors.onSecondaryContainer,
    tertiary: AriseColors.tertiary,
    onTertiary: AriseColors.onTertiary,
    tertiaryContainer: AriseColors.tertiaryContainer,
    onTertiaryContainer: AriseColors.onTertiaryContainer,
    error: AriseColors.error,
    onError: AriseColors.onError,
    errorContainer: AriseColors.errorContainer,
    onErrorContainer: AriseColors.onErrorContainer,
    surface: AriseColors.surface,
    onSurface: AriseColors.onSurface,
    onSurfaceVariant: AriseColors.onSurfaceVariant,
    outline: AriseColors.outline,
    outlineVariant: AriseColors.outlineVariant,
    inverseSurface: AriseColors.inverseSurface,
    onInverseSurface: AriseColors.inverseOnSurface,
    inversePrimary: AriseColors.inversePrimary,
    surfaceTint: AriseColors.surfaceTint,
    surfaceContainerLowest: AriseColors.surfaceContainerLowest,
    surfaceContainerLow: AriseColors.surfaceContainerLow,
    surfaceContainer: AriseColors.surfaceContainer,
    surfaceContainerHigh: AriseColors.surfaceContainerHigh,
    surfaceContainerHighest: AriseColors.surfaceContainerHighest,
    surfaceBright: AriseColors.surfaceBright,
    surfaceDim: AriseColors.surfaceDim,
  );

  // ── ThemeData ─────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: AriseColors.background,
      cardTheme: CardThemeData(
        color: AriseColors.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      iconTheme: const IconThemeData(
        color: AriseColors.onSurfaceVariant,
        size: 22,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent, // "No-Line" rule
        thickness: 0,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          AriseColors.outlineVariant.withValues(alpha: 0.4),
        ),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}
