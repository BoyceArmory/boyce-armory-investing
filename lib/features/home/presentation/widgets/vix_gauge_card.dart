import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/home_providers.dart';

/// VIX volatility gauge. Self-contained card you can drop into the home page
/// stack. Returns SizedBox.shrink() if VIX is unavailable so the layout
/// gracefully collapses.
class VixGaugeCard extends ConsumerWidget {
  const VixGaugeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);
    return async.maybeWhen(
      data: (o) {
        final vix = o.vix;
        if (vix == null) return const SizedBox.shrink();
        final v = vix.price;
        Color color;
        String label;
        if (v < 15) { color = AppColors.bullish; label = 'CALM'; }
        else if (v < 20) { color = AppColors.bullish; label = 'NORMAL'; }
        else if (v < 28) { color = AppColors.warning; label = 'CAUTIOUS'; }
        else { color = AppColors.bearish; label = 'FEARFUL'; }
        final pos = (v / 40).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.steel),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('VIX',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                  const Spacer(),
                  Text(v.toStringAsFixed(2),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.bullish, AppColors.bullish, AppColors.warning, AppColors.bearish,
                        ], stops: [0, 0.4, 0.62, 1]),
                      ),
                    ),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pos,
                        child: Container(
                          alignment: Alignment.centerRight,
                          child: Container(width: 2, height: 14, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                  Text('15', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                  Text('20', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                  Text('28', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                  Text('40+', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
