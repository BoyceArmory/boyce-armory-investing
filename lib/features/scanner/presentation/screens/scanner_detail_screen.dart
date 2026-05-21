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
                        value: alert.riskRewardRatio != null
                            ? alert.riskRewardRatio!.toStringAsFixed(2)
                            : '-',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (alert.suggestedContract != null) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: PremiumCard(
              accent: PremiumCardAccent.gold,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.local_offer_outlined,
                          color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Text('Suggested contract', style: tt.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alert.suggestedContract!.symbol,
                    style: AppTypography.mono(
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alert.suggestedContract!.type.toUpperCase()} '
                    '${Formatters.priceCompact(alert.suggestedContract!.strike)} '
                    '· ${alert.suggestedContract!.expiration}',
                    style: tt.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
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
