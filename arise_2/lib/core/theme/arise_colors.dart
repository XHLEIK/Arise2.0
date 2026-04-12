import 'dart:ui';

/// All named color tokens from the Stitch "Cinematic Intelligence Framework"
/// design system. These follow the "Void and Neon" philosophy — deep obsidian
/// tones grounded by sharp electric accents.
class AriseColors {
  AriseColors._();

  // ── Surfaces ──────────────────────────────────────────────────────────
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF3A3939);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  static const Color surfaceVariant = Color(0xFF353534);

  // ── Primary (Cyan/Aqua) ───────────────────────────────────────────────
  static const Color primary = Color(0xFFC3F5FF);
  static const Color primaryContainer = Color(0xFF00E5FF);
  static const Color primaryFixed = Color(0xFF9CF0FF);
  static const Color primaryFixedDim = Color(0xFF00DAF3);
  static const Color onPrimary = Color(0xFF00363D);
  static const Color onPrimaryContainer = Color(0xFF00626E);
  static const Color onPrimaryFixed = Color(0xFF001F24);
  static const Color surfaceTint = Color(0xFF00DAF3);

  // ── Secondary (Violet) ────────────────────────────────────────────────
  static const Color secondary = Color(0xFFD8B9FF);
  static const Color secondaryContainer = Color(0xFF6E06D0);
  static const Color secondaryFixed = Color(0xFFEDDCFF);
  static const Color secondaryFixedDim = Color(0xFFD8B9FF);
  static const Color onSecondary = Color(0xFF450086);
  static const Color onSecondaryContainer = Color(0xFFD5B5FF);

  // ── Tertiary (Neutral White) ──────────────────────────────────────────
  static const Color tertiary = Color(0xFFECECEC);
  static const Color tertiaryContainer = Color(0xFFD0D0D0);
  static const Color onTertiary = Color(0xFF2F3131);
  static const Color onTertiaryContainer = Color(0xFF575959);

  // ── On-Surface & Outline ──────────────────────────────────────────────
  static const Color onBackground = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFBAC9CC);
  static const Color outline = Color(0xFF849396);
  static const Color outlineVariant = Color(0xFF3B494C);

  // ── Error ─────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // ── Inverse ───────────────────────────────────────────────────────────
  static const Color inverseSurface = Color(0xFFE5E2E1);
  static const Color inverseOnSurface = Color(0xFF313030);
  static const Color inversePrimary = Color(0xFF006875);

  // ── Semantic helpers ──────────────────────────────────────────────────
  static const Color neonGlow = Color(0x1F00E5FF); // 12% primary glow
  static const Color ghostBorder = Color(0x263B494C); // 15% outlineVariant
  static const Color glassBg = Color(0x66353534); // 40% surfaceVariant
  static const Color aiPulse = Color(0xFFD8B9FF); // secondary breathing
}
