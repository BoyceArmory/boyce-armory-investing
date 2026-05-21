import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

/// Foundational card for the app: graphite gradient, hairline border,
/// optional gold/bull/bear accent edge for emphasis.
enum PremiumCardAccent { none, gold, bullish, bearish }

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.accent = PremiumCardAccent.none,
    this.glow = false,
    this.borderRadius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final PremiumCardAccent accent;
  final bool glow;
  final double borderRadius;

  Color get _accentColor {
    switch (accent) {
      case PremiumCardAccent.gold:
        return AppColors.gold;
      case PremiumCardAccent.bullish:
        return AppColors.bullish;
      case PremiumCardAccent.bearish:
        return AppColors.bearish;
      case PremiumCardAccent.none:
        return AppColors.steel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Widget body = Container(
      decoration: BoxDecoration(
        gradient: AppGradients.premiumCard,
        borderRadius: radius,
        border: Border.all(
          color: accent == PremiumCardAccent.none
              ? AppColors.steel
              : _accentColor.withValues(alpha: 0.45),
        ),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: _accentColor.withValues(alpha: 0.06),
        highlightColor: _accentColor.withValues(alpha: 0.04),
        child: body,
      ),
    );
  }
}
