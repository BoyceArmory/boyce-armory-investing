import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/home_providers.dart';

class DeskPerformanceCard extends ConsumerWidget {
  const DeskPerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);

    return async.maybeWhen(
      data: (o) {
        final p = o.performance;

        if (p == null || p.totalTrades == 0) {
          return const SizedBox.shrink();
        }

        final winColor = p.winRate >= 60
            ? AppColors.bullish
            : (p.winRate >= 50
                ? AppColors.warning
                : AppColors.bearish);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go(RoutePaths.performance),
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    'assets/backgrounds/blank_backgrounds.png',
                  ),
                  fit: BoxFit.cover,
                  opacity: 0.20,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.insights_outlined,
                    color: AppColors.gold,
                    size: 20,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'DESK PERFORMANCE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${p.totalTrades} trades tracked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Stat(
                          label: 'WIN RATE',
                          value:
                              '${p.winRate.toStringAsFixed(1)}%',
                          color: winColor,
                        ),
                      ),

                      Expanded(
                        child: _Stat(
                          label: 'AVG WIN',
                          value:
                              '+${p.avgGainPct.toStringAsFixed(1)}%',
                          color: AppColors.bullish,
                        ),
                      ),

                      Expanded(
                        child: _Stat(
                          label: 'AVG LOSS',
                          value:
                              '-${p.avgLossPct.toStringAsFixed(1)}%',
                          color: AppColors.bearish,
                        ),
                      ),
                    ],
                  ),

                  if (p.bestTradePct > 0 ||
                      p.worstTradePct != 0) ...<Widget>[
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: <Widget>[
                        if (p.bestTradePct > 0)
                          ...<Widget>[
                            const Icon(
                              Icons.arrow_upward,
                              size: 13,
                              color: AppColors.bullish,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              'Best +${p.bestTradePct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: AppColors.bullish,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],

                        if (p.bestTradePct > 0 &&
                            p.worstTradePct != 0)
                          const SizedBox(width: 18),

                        if (p.worstTradePct != 0)
                          ...<Widget>[
                            const Icon(
                              Icons.arrow_downward,
                              size: 13,
                              color: AppColors.bearish,
                            ),

                            const SizedBox(width: 4),

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
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTypography.mono(
            size: 20,
            weight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}