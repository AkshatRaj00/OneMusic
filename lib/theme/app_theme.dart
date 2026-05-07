import 'package:flutter/material.dart';

enum AppThemeMode { aura, volt, blaze, cosmos }

class AppTheme {
  final AppThemeMode mode;
  const AppTheme(this.mode);

  // ── Backgrounds ──────────────────────────
  Color get background => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF0A0008),
    AppThemeMode.volt   => const Color(0xFF000000),
    AppThemeMode.blaze  => const Color(0xFF0F0A00),
    AppThemeMode.cosmos => const Color(0xFF020817),
  };

  Color get surface => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF1A0A22),
    AppThemeMode.volt   => const Color(0xFF0A0A0A),
    AppThemeMode.blaze  => const Color(0xFF1A1000),
    AppThemeMode.cosmos => const Color(0xFF040D20),
  };

  Color get surfaceAlt => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF240F30),
    AppThemeMode.volt   => const Color(0xFF0F0F0F),
    AppThemeMode.blaze  => const Color(0xFF251800),
    AppThemeMode.cosmos => const Color(0xFF071028),
  };

  // ── Accents ──────────────────────────────
  Color get accent => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF9B5DE5),
    AppThemeMode.volt   => const Color(0xFF39FF14),
    AppThemeMode.blaze  => const Color(0xFFFF6B35),
    AppThemeMode.cosmos => const Color(0xFF00D4FF),
  };

  Color get accentSecondary => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF4361EE),
    AppThemeMode.volt   => const Color(0xFF00F5A0),
    AppThemeMode.blaze  => const Color(0xFFF7197A),
    AppThemeMode.cosmos => const Color(0xFF7B2FFF),
  };

  // ── Gradient ─────────────────────────────
  LinearGradient get accentGradient => LinearGradient(
    colors: [accent, accentSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get backgroundGradient => LinearGradient(
    colors: [background, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Text ─────────────────────────────────
  Color get textPrimary => switch (mode) {
    AppThemeMode.aura   => const Color(0xFFE8D5FF),
    AppThemeMode.volt   => const Color(0xFFD4FFCC),
    AppThemeMode.blaze  => const Color(0xFFFFD5C2),
    AppThemeMode.cosmos => const Color(0xFFC8F0FF),
  };

  Color get textSecondary => textPrimary.withOpacity(0.6);
  Color get textMuted     => textPrimary.withOpacity(0.35);

  // ── Card ─────────────────────────────────
  Color get cardBackground => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF9B5DE5).withOpacity(0.08),
    AppThemeMode.volt   => const Color(0xFF39FF14).withOpacity(0.05),
    AppThemeMode.blaze  => const Color(0xFFFF6B35).withOpacity(0.08),
    AppThemeMode.cosmos => const Color(0xFF00D4FF).withOpacity(0.06),
  };

  Color get cardBorder => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF9B5DE5).withOpacity(0.25),
    AppThemeMode.volt   => const Color(0xFF39FF14).withOpacity(0.30),
    AppThemeMode.blaze  => const Color(0xFFFF6B35).withOpacity(0.25),
    AppThemeMode.cosmos => const Color(0xFF00D4FF).withOpacity(0.20),
  };

  // ── Glow ─────────────────────────────────
  Color get glowColor => switch (mode) {
    AppThemeMode.aura   => const Color(0xFF9B5DE5).withOpacity(0.4),
    AppThemeMode.volt   => const Color(0xFF39FF14).withOpacity(0.4),
    AppThemeMode.blaze  => const Color(0xFFFF6B35).withOpacity(0.4),
    AppThemeMode.cosmos => const Color(0xFF00D4FF).withOpacity(0.35),
  };

  List<BoxShadow> get glowShadow => [
    BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 0),
    BoxShadow(color: glowColor.withOpacity(0.2), blurRadius: 40),
  ];

  BoxDecoration get glassCard => BoxDecoration(
    color:        cardBackground,
    borderRadius: BorderRadius.circular(20),
    border:       Border.all(color: cardBorder, width: 1),
  );

  // ── Theme Meta ───────────────────────────
  String get displayName => switch (mode) {
    AppThemeMode.aura   => 'AURA',
    AppThemeMode.volt   => 'VOLT',
    AppThemeMode.blaze  => 'BLAZE',
    AppThemeMode.cosmos => 'COSMOS',
  };

  String get emoji => switch (mode) {
    AppThemeMode.aura   => '🌊',
    AppThemeMode.volt   => '⚡',
    AppThemeMode.blaze  => '🌅',
    AppThemeMode.cosmos => '🪐',
  };

  String get vibe => switch (mode) {
    AppThemeMode.aura   => 'Glassmorphism Dark',
    AppThemeMode.volt   => 'Neon Energy',
    AppThemeMode.blaze  => 'Warm Dark',
    AppThemeMode.cosmos => 'Space Dark',
  };

  // ── Flutter ThemeData ────────────────────
  ThemeData get themeData => ThemeData(
    useMaterial3:     true,
    brightness:       Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.dark(
      primary:    accent,
      secondary:  accentSecondary,
      surface:    surface,
      onPrimary:  Colors.white,
      onSurface:  textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation:       0,
      iconTheme:       IconThemeData(color: textPrimary),
      titleTextStyle:  TextStyle(
        color:      accent,
        fontSize:   20,
        fontWeight: FontWeight.w800,
      ),
    ),
    iconTheme: IconThemeData(color: textPrimary),
    textTheme: TextTheme(
      bodyLarge:  TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall:  TextStyle(color: textMuted),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor:   accent,
      thumbColor:         accent,
      inactiveTrackColor: textMuted,
      overlayColor:       glowColor,
    ),
    switchTheme: SwitchThemeData(
      thumbColor:  WidgetStateProperty.all(accent),
      trackColor:  WidgetStateProperty.all(cardBorder),
    ),
  );
}