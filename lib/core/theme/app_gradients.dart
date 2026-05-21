import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Reusable gradients for premium surfaces.
class AppGradients {
  AppGradients._();

  /// Subtle background gradient for app shells.
  static const LinearGradient appBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF050608), Color(0xFF0A0C10)],
  );

  /// Premium card gradient - graphite to carbon with a faint sheen.
  static const LinearGradient premiumCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1E25), Color(0xFF0E1014)],
  );

  /// Gold gradient for CTAs and highlights.
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.goldBright, AppColors.gold, AppColors.goldMuted],
    stops: [0.0, 0.55, 1.0],
  );

  /// Bullish glow - green to transparent.
  static const RadialGradient bullishGlow = RadialGradient(
    colors: [Color(0x4022C55E), Color(0x0022C55E)],
  );

  /// Bearish glow - red to transparent.
  static const RadialGradient bearishGlow = RadialGradient(
    colors: [Color(0x40EF4444), Color(0x00EF4444)],
  );
}
