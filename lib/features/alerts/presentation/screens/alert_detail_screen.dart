import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/stat_chip.dart';
import '../../../scanner/presentation/widgets/direction_indicator.dart';
import '../../../scanner/presentation/widgets/grade_badge.dart';
import '../providers/alerts_providers.dart';

class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({super.key, required this.alertId});
  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TradeAlert?> async =
        ref.watch(alertByIdProvider(alertId));
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: const Text('Trade alert'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/hot-trades'),
        ),
      ),
      body: async.when(
        loading: () => const LoadingIndicator(label: 'Loading alert'),
        error: (Object e, _) => ErrorState(
          message: 'Could not load this alert.',
          details: e.toString(),
          onRetry: () => ref.invalidate(alertByIdProvider(alertId)),
        ),
        data: (TradeAlert? a) {
          if (a == null) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Alert not found',
              message: 'This alert may have been removed.',
            );
          }
          return _Body(alert: a);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        FadeSlideIn(
          child: PremiumCard(
            accent: alert.isHot
                ? PremiumCardAccent.gold
                : (alert.isBullish
                    ? PremiumCardAccent.bullish
                    : PremiumCardAccent.bearish),
            glow: alert.isHot,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (alert.isHot)
                  Row(
                    children: <Widget>[
                      const Icon(Icons.local_fire_department,
                          color: AppColors.gold, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'HOT TRADE',
                        style: tt.labelSmall
                            ?.copyWith(color: AppColors.gold, letterSpacing: 1),
                      ),
                    ],
                  ),
                if (alert.isHot) const SizedBox(height: 10),
                Text(
                  alert.symbol,
                  style: AppTypography.mono(
                    size: 30,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    DirectionIndicator(direction: alert.direction),
                    if (alert.grade != null) ...<Widget>[
                      const SizedBox(width: 8),
                      GradeBadge(grade: alert.grade!),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
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
                        label: 'Confidence',
                        value: '${alert.confidence}',
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniStat(
                        label: 'Source',
                        value: alert.source.toUpperCase(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (alert.contract != null) ...<Widget>[
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
                    alert.contract!.symbol,
                    style: AppTypography.mono(
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${alert.contract!.type.toUpperCase()} '
                    '${Formatters.priceCompact(alert.contract!.strike)} '
                    '· ${alert.contract!.expiration}',
                    style: tt.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (alert.notes != null && alert.notes!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 180),
            child: PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Notes', style: tt.titleMedium),
                  const SizedBox(height: 10),
                  Text(alert.notes!, style: tt.bodyLarge),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 220),
          child: Text(
            'Posted ${alert.createdAt.ago} · channel ${alert.channel.wire}',
            style: tt.bodySmall,
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
