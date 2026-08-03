import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/models/scanner_alert_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/stat_chip.dart';
import '../providers/scanner_providers.dart';
import '../widgets/direction_indicator.dart';
import '../widgets/grade_badge.dart';
import '../widgets/score_ring.dart';

class ScannerDetailScreen extends ConsumerWidget {
  const ScannerDetailScreen({super.key, required this.scannerId});
  final String scannerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ScannerAlert?> async =
        ref.watch(scannerAlertByIdProvider(scannerId));
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: const Text('Setup detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/scanner'),
        ),
      ),
      body: async.when(
        loading: () => const LoadingIndicator(label: 'Loading setup'),
        error: (Object e, _) => ErrorState(
          message: 'Could not load this setup.',
          details: e.toString(),
          onRetry: () => ref.invalidate(scannerAlertByIdProvider(scannerId)),
        ),
        data: (ScannerAlert? a) {
          if (a == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Setup not found',
              message: 'This signal may have been removed or expired.',
            );
          }
          return _DetailBody(alert: a);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.alert});
  final ScannerAlert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        FadeSlideIn(
          child: PremiumCard(
            accent: alert.promoted
                ? PremiumCardAccent.gold
                : (alert.isBullish
                    ? PremiumCardAccent.bullish
                    : PremiumCardAccent.bearish),
            glow: alert.promoted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            alert.symbol,
                            style: AppTypography.mono(
                              size: 30,
                              weight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              DirectionIndicator(direction: alert.direction),
                              const SizedBox(width: 8),
                              GradeBadge(grade: alert.grade),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alert.kind.replaceAll('_', ' ').toUpperCase(),
                            style: tt.labelMedium?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ScoreRing(score: alert.score, size: 80),
                  ],
                ),
                const SizedBox(height: 22),
                Text('Why this setup', style: tt.titleMedium),
                const SizedBox(height: 6),
                Text(alert.reason, style: tt.bodyLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Trade plan', style: tt.titleMedium),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: StatChip(
                        label: 'Entry',
                        value: Formatters.price(alert.entry),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatChip(
                        label: 'Target',
                        value: Formatters.price(alert.target),
                        color: AppColors.bullish,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatChip(
                        label: 'Stop',
                        value: Formatters.price(alert.stop),
                        color: AppColors.bearish,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Scaled-exit ladder. Only renders when the backend supplied
                // T1/T2/T3 (engine.buildResult after Sprint 1). Older alerts
                // without these fields fall through quietly.
                if (alert.target1 != null &&
                    alert.target2 != null &&
                    alert.target3 != null) ...<Widget>[
                  Text(
                    'Scaled exits',
                    style: tt.labelLarge?.copyWith(
                        color: AppColors.textTertiary, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _LadderRung(
                          label: 'T1 · 1R',
                          value: Formatters.price(alert.target1),
                          color: AppColors.bullish.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _LadderRung(
                          label: 'T2 · 2R',
                          value: Formatters.price(alert.target2),
                          color: AppColors.bullish,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _LadderRung(
                          label: 'T3 · 3R',
                          value: Formatters.price(alert.target3),
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scale 1/3 of position at each level. R = entry-to-stop distance.',
                    style: tt.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        label: 'Target move',
                        value: alert.targetMovePct != null
                            ? Formatters.signedPercent(
                                alert.targetMovePct,
                                alreadyPercent: true,
                              )
                            : '-',
                        color: alert.isBullish
                            ? AppColors.bullish
                            : AppColors.bearish,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'R / R',
                        value: (alert.riskReward ?? alert.riskRewardRatio) != null
                            ? (alert.riskReward ?? alert.riskRewardRatio)!
                                .toStringAsFixed(2)
                            : '-',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Published ${alert.createdAt.ago}',
                style: tt.bodySmall,
              ),
              if (alert.asOf != null)
                Text(
                  'as of ${alert.asOf!.shortDate}',
                  style: tt.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.mono(
              size: 18,
              weight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single rung of the scaled-exit ladder shown on the detail screen.
/// Layout: small uppercase label on top, monospace price below.
class _LadderRung extends StatelessWidget {
  const _LadderRung({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.mono(
              size: 15,
              weight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
