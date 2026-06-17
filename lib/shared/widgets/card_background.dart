import 'package:flutter/material.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

/// What kind of card background art to use.
/// Assets are full-bleed - the image spans the entire card. All content the
/// caller renders sits *on top* of the image, so callers should keep heavy
/// content out of the left half (the artwork focal area).
enum CardArt {
  /// Default - no background image. Premium dark gradient instead.
  none,

  /// Bullish call setup background art.
  bullCall,

  /// Bearish put setup background art.
  bearPut,

  /// Closed trade - won.
  closedWin,

  /// Closed trade - lost.
  closedLoss,

  /// Smart money flow - bullish bias.
  smartMoneyBull,

  /// Smart money flow - bearish bias.
  smartMoneyBear,
}

extension CardArtAsset on CardArt {
  String? get assetPath {
    switch (this) {
      case CardArt.none:
        return null;
      case CardArt.bullCall:
        return AssetPaths.bgBullCall;
      case CardArt.bearPut:
        return AssetPaths.bgBearPut;
      case CardArt.closedWin:
        return AssetPaths.bgClosedWin;
      case CardArt.closedLoss:
        return AssetPaths.bgClosedLoss;
      case CardArt.smartMoneyBull:
        return AssetPaths.bgSmartMoneyBull;
      case CardArt.smartMoneyBear:
        return AssetPaths.bgSmartMoneyBear;
    }
  }
}

/// Full-bleed card chrome. The art asset fills the entire card; no dark
/// overlay or gradient scrim sits on top of it. A thin border defines the
/// edge and an optional outer glow can highlight promoted cards - neither
/// obscures the artwork.
class CardBackground extends StatelessWidget {
  const CardBackground({
    super.key,
    required this.child,
    this.art = CardArt.none,
    this.accentColor,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(18),
    this.minHeight = 200,
    this.glow = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final CardArt art;
  final Color? accentColor;
  final double borderRadius;
  final EdgeInsets padding;

  /// Minimum card height so the artwork has room to breathe.
  final double minHeight;

  final bool glow;
  final VoidCallback? onTap;
  /// Long-press handler — surfaces a power-user action sheet (share,
  /// watchlist, copy plan, open chart, etc.). Independent of [onTap].
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Color border = (accentColor ?? AppColors.steel).withValues(
      alpha: accentColor == null ? 1 : 0.55,
    );

    final Widget body = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
        // Outer glow only - never overlaps the image. Optional.
        boxShadow: glow && accentColor != null
            ? <BoxShadow>[
                BoxShadow(
                  color: accentColor!.withValues(alpha: 0.20),
                  blurRadius: 22,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            // Layer 1: artwork OR fallback gradient. Full-bleed.
            Positioned.fill(
              child: art.assetPath != null
                  ? Image.asset(
                      art.assetPath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.premiumCard,
                        ),
                      ),
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.premiumCard,
                      ),
                    ),
            ),
            // Layer 2: content. Callers control the layout; this widget
            // intentionally does NOT add a scrim so the image stays clear.
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null && onLongPress == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: (accentColor ?? AppColors.gold).withValues(alpha: 0.06),
        highlightColor:
            (accentColor ?? AppColors.gold).withValues(alpha: 0.04),
        child: body,
      ),
    );
  }
}
