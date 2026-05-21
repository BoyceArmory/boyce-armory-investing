import 'package:flutter/material.dart';

/// Brand palette for Boyce Armory.
///
/// Dark luxury aesthetic - black base with refined dark grays and gold accents.
/// Greens/reds are reserved for bullish/bearish directional cues.
class AppColors {
  AppColors._();

  // --- Brand surface ---
  static const Color obsidian = Color(0xFF050608);   // app background
  static const Color carbon = Color(0xFF0C0E12);     // surface
  static const Color graphite = Color(0xFF15181E);   // elevated surface
  static const Color steel = Color(0xFF1F242C);      // borders / dividers
  static const Color slate = Color(0xFF2A2F38);      // subtle separators

  // --- Brand accents ---
  static const Color gold = Color(0xFFCFAE57);       // primary gold
  static const Color goldBright = Color(0xFFE9C77B); // hover / highlight
  static const Color goldMuted = Color(0xFF7A6532);  // disabled / subdued

  // --- Directional ---
  static const Color bullish = Color(0xFF22C55E);
  static const Color bullishMuted = Color(0xFF14532D);
  static const Color bearish = Color(0xFFEF4444);
  static const Color bearishMuted = Color(0xFF5B1212);

  // --- Status ---
  static const Color info = Color(0xFF60A5FA);
  static const Color warning = Color(0xFFF59E0B);

  // --- Text ---
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFFB6BBC4);
  static const Color textTertiary = Color(0xFF7C8290);
  static const Color textDisabled = Color(0xFF4A4F58);

  // --- Glass / overlays ---
  static const Color overlay = Color(0xCC000000);
  static const Color hairline = Color(0x1FFFFFFF);
}
