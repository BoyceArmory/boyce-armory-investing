import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/home_providers.dart';

/// Desk performance card. Shows global win-rate + trade counts so users can
/// glance at the track record without leaving the home page. Tapping the
/// card navigates to the full Performance screen at /performance.
class DeskPerformanceCard extends ConsumerWidget {
  const DeskPerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);
    return async.maybeWhen(
      data: (o) {
        final p = o.performance;
        if (p == null || p.totalTrades == 0) return const SizedBox.shrink();
        final winColor = p.winRate >= 60
            ? AppColors.bullish
            : (p.winRate >= 50 ? AppColors.warning : AppColors.bearish);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(RoutePaths.performance),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.graphite,
                border: Border.all(color: AppColors.steel),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.insights_outlined,
                          color: AppColors.gold, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'DESK PERFORMANCE',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${p.totalTrades} trades',
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Stat(
                          label: 'WIN RATE',
                          value: '${p.winRate.toStringAsFixed(1)}%',
                          color: winColor,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'AVG WIN',
                          value: '+${p.avgGainPct.toStringAsFixed(1)}%',
                          color: AppColors.bullish,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'AVG LOSS',
                          value: '-${p.avgLossPct.toStringAsFixed(1)}%',
                          color: AppColors.bearish,
                        ),
                      ),
                    ],
                  ),
                  if (p.bestTradePct > 0 || p.worstTradePct != 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        if (p.bestTradePct > 0) ...<Widget>[
                          const Icon(Icons.arrow_upward,
                              size: 11, color: AppColors.bullish),
                          const SizedBox(width: 3),
                          Text(
                            'Best +${p.bestTradePct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.bullish,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (p.worstTradePct != 0) ...<Widget>[
                          const Icon(Icons.arrow_downward,
                              size: 11, color: AppColors.bearish),
                          const SizedBox(width: 3),
                          Text(
                            'Worst ${p.worstTradePct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.bearish,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.mono(
            size: 18,
            weight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
