import 'package:flutter/material.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';

/// Renders the logo for a ticker symbol from `assets/ticker_logos/{SYMBOL}.png`.
/// Gracefully degrades to a circular badge with the ticker's initials when the
/// asset is missing (we have 5k+ tickers but we'll never have *every* one).
class TickerLogo extends StatelessWidget {
  const TickerLogo({
    super.key,
    required this.symbol,
    this.size = 44,
    this.borderRadius = 14,
  });

  final String symbol;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.carbon,
          border: Border.all(color: AppColors.steel),
        ),
        child: Image.asset(
          AssetPaths.tickerLogo(symbol),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Fallback(symbol: symbol, size: size),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.symbol, required this.size});
  final String symbol;
  final double size;

  String get _initials {
    final String s = symbol.trim();
    if (s.isEmpty) return '?';
    return s.length <= 4 ? s.toUpperCase() : s.substring(0, 4).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: AppColors.graphite,
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.28,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
