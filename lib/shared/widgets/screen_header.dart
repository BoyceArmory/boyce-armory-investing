import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Full-width banner header used at the top of major screens.
///
/// By default the image is drawn at full width using its natural aspect ratio
/// (`BoxFit.fitWidth`), so the whole image is visible with no crop. Pass an
/// explicit [aspectRatio] only if you intentionally want the image
/// constrained to a fixed shape (and accept that `BoxFit.cover` will crop it).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.asset,
    this.aspectRatio,
    this.fadeBottom = true,
    this.padding = EdgeInsets.zero,
  });

  /// Asset path, e.g. `AssetPaths.headerHome`.
  final String asset;

  /// Optional forced aspect ratio. Leave null to use the image's natural ratio
  /// (recommended - prevents cropping).
  final double? aspectRatio;

  /// Render a short gradient fade at the bottom so the banner blends into
  /// the obsidian app background.
  final bool fadeBottom;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final Widget image = aspectRatio == null
        ? Image.asset(
            asset,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: AppColors.carbon,
            ),
          )
        : AspectRatio(
            aspectRatio: aspectRatio!,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.carbon,
              ),
            ),
          );

    final Widget stacked = Stack(
      children: <Widget>[
        image,
        if (fadeBottom)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x00050608),
                    Color(0xFF050608),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (padding == EdgeInsets.zero) return stacked;
    return Padding(padding: padding, child: stacked);
  }
}
