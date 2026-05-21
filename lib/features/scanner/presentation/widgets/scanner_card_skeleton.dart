import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/shimmer_loading.dart';

/// Skeleton placeholder for the scanner card. Used during initial load.
class ScannerCardSkeleton extends StatelessWidget {
  const ScannerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.steel),
      ),
      padding: const EdgeInsets.all(18),
      child: ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const ShimmerBar(width: 70, height: 22),
                const SizedBox(width: 10),
                const ShimmerBar(width: 60, height: 18, radius: 999),
                const Spacer(),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.graphite,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBar(),
            const SizedBox(height: 8),
            const ShimmerBar(width: 180),
            const SizedBox(height: 18),
            const Row(
              children: <Widget>[
                Expanded(child: ShimmerBar(height: 38, radius: 10)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBar(height: 38, radius: 10)),
                SizedBox(width: 8),
                Expanded(child: ShimmerBar(height: 38, radius: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
