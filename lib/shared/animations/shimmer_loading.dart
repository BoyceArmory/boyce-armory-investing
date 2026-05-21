import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

/// Brand-tinted shimmer placeholder. Wrap any skeleton shapes with this.
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.graphite,
      highlightColor: AppColors.steel,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Single rounded skeleton bar. Compose for richer placeholders.
class ShimmerBar extends StatelessWidget {
  const ShimmerBar({
    super.key,
    this.height = 14,
    this.width = double.infinity,
    this.radius = 6,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
