import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Premium dark background layer used behind major screens.
/// Two soft radial glows (gold top-left, faint bull/bear bottom-right) sit
/// behind a near-black gradient. Wrap any screen body in this for the
/// Bloomberg/luxury-fintech atmosphere.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.accentColor,
  });

  final Widget child;

  /// Optional accent for the secondary glow (e.g. green on bullish detail
  /// screens, red on bearish). Defaults to a faint gold.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        (accentColor ?? AppColors.gold).withValues(alpha: 0.08);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Base gradient (obsidian -> carbon).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF050608), Color(0xFF0A0C10)],
            ),
          ),
        ),
        // Gold glow (top-left).
        Positioned(
          top: -120,
          left: -120,
          child: _Glow(
            color: AppColors.gold.withValues(alpha: 0.10),
            size: 360,
          ),
        ),
        // Secondary glow (bottom-right) - accent color when provided.
        Positioned(
          bottom: -160,
          right: -160,
          child: _Glow(color: accent, size: 420),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
