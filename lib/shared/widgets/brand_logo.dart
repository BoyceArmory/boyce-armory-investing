import 'package:flutter/material.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';

enum BrandLogoVariant {
  /// Compact square mark, suitable for app bars, avatars, badges.
  mark,

  /// Full logo with wordmark/illustration, suitable for splash + login.
  full,
}

/// Brand logo widget. Uses [AssetPaths.brandLogo] / [AssetPaths.splashLogo].
/// If the asset is missing for any reason, falls back to a gold-gradient "BA"
/// mark so the UI is never broken.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.variant = BrandLogoVariant.mark,
    this.size = 48,
    this.padding = EdgeInsets.zero,
    this.glow = false,
  });

  /// Use this for app bars / row leading widgets - rounded gold-bordered mark.
  const BrandLogo.mark({super.key, this.size = 40, this.glow = false})
      : variant = BrandLogoVariant.mark,
        padding = EdgeInsets.zero;

  /// Use this for splash + login - centered, large, with optional glow.
  const BrandLogo.full({super.key, this.size = 120, this.glow = true})
      : variant = BrandLogoVariant.full,
        padding = EdgeInsets.zero;

  final BrandLogoVariant variant;
  final double size;
  final EdgeInsets padding;
  final bool glow;

  String get _asset => switch (variant) {
        BrandLogoVariant.mark => AssetPaths.brandLogo,
        BrandLogoVariant.full => AssetPaths.splashLogo,
      };

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _Fallback(size: size, variant: variant),
    );

    final Widget wrapped = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          variant == BrandLogoVariant.mark ? size * 0.22 : 20,
        ),
        boxShadow: glow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x55CFAE57),
                  blurRadius: 36,
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          variant == BrandLogoVariant.mark ? size * 0.22 : 20,
        ),
        child: image,
      ),
    );

    if (padding == EdgeInsets.zero) return wrapped;
    return Padding(padding: padding, child: wrapped);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.size, required this.variant});
  final double size;
  final BrandLogoVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.gold,
        borderRadius: BorderRadius.circular(
          variant == BrandLogoVariant.mark ? size * 0.22 : 20,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'BA',
        style: TextStyle(
          color: AppColors.obsidian,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
