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
import '../../../../shared/widgets/risk_calculator_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/stat_chip.dart';
import '../../../scanner/data/setup_education.dart';
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
        actions: <Widget>[
          IconButton(
            tooltip: 'Risk calculator',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              final a = ref.read(alertByIdProvider(alertId)).asData?.value;
              if (a == null) return;
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RiskCalculatorSheet(
                  symbol: a.symbol,
                  entry: a.entry,
                  stop: a.stop,
                ),
              );
            },
          ),
        ],
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
        // ---- R-multiple breakdown (computed from entry/stop/target) -------
        if (alert.stop != null && alert.target != null) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: _RMultipleCard(alert: alert),
          ),
        ],
        // ---- Why this setup works (educational explainer) -----------------
        if (alert.kind.isNotEmpty && alert.kind != 'manual') ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: _WhyThisSetupCard(kind: alert.kind),
          ),
        ],
        // ---- Live price + day move ----------------------------------------
        if (alert.currentPrice != null) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: _LivePriceCard(alert: alert),
          ),
        ],
        // ---- What invalidates this setup ----------------------------------
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: _InvalidationCard(alert: alert),
        ),
        if (alert.contract != null) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
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

/// Risk:reward breakdown panel. Renders the R-multiple (reward ÷ risk),
/// the absolute dollar move at 1R/2R/3R, and a tiny visual bar that shows
/// the trade's reward-to-risk ratio at a glance.
class _RMultipleCard extends StatelessWidget {
  const _RMultipleCard({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final double risk = (alert.entry - (alert.stop ?? alert.entry)).abs();
    final double reward = ((alert.target ?? alert.entry) - alert.entry).abs();
    final double rMult = risk > 0 ? reward / risk : 0;
    final bool good = rMult >= 1.5;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.balance, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('Risk : Reward', style: tt.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (good ? AppColors.bullish : AppColors.bearish)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: (good ? AppColors.bullish : AppColors.bearish)
                          .withValues(alpha: 0.55)),
                ),
                child: Text(
                  '${rMult.toStringAsFixed(1)}R',
                  style: AppTypography.mono(
                    size: 14,
                    weight: FontWeight.w800,
                    color: good ? AppColors.bullish : AppColors.bearish,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Visual bar — left red (risk), right green (reward), proportional.
          Row(
            children: <Widget>[
              Expanded(
                flex: (risk * 100).round().clamp(1, 1000),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.bearish,
                    borderRadius:
                        const BorderRadius.horizontal(left: Radius.circular(4)),
                  ),
                ),
              ),
              Expanded(
                flex: (reward * 100).round().clamp(1, 1000),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.bullish,
                    borderRadius:
                        const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                '-\$${risk.toStringAsFixed(2)} risk',
                style: const TextStyle(
                  color: AppColors.bearish,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '+\$${reward.toStringAsFixed(2)} target',
                style: const TextStyle(
                  color: AppColors.bullish,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            good
                ? 'Healthy ratio. You only need a ${(100 / (rMult + 1)).round()}% win rate over time to be profitable on this setup.'
                : 'Sub-1.5R reward:risk. Consider waiting for a deeper pullback to entry, or tightening the stop.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Educational explainer for the setup family. Reads from
/// `SetupEducation.forKind(kind)` so detector additions automatically get
/// their copy on this screen.
class _WhyThisSetupCard extends StatelessWidget {
  const _WhyThisSetupCard({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final String explainer = SetupEducation.forKind(kind);
    final String prettyKind = kind.replaceAll('_', ' ').toUpperCase();
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.school_outlined,
                  color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('Why this setup works', style: tt.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Text(
                  prettyKind,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explainer,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Live price + day-change panel. Shows where the underlying is RIGHT NOW
/// vs the entry the alert was published with, so users can immediately tell
/// "am I early, on time, or chasing."
class _LivePriceCard extends StatelessWidget {
  const _LivePriceCard({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final double now = alert.currentPrice ?? alert.entry;
    final double drift = ((now - alert.entry) / alert.entry) * 100;
    final bool chasing =
        alert.isBullish ? drift > 1.0 : drift < -1.0;
    final bool good =
        alert.isBullish ? drift.abs() < 0.5 : drift.abs() < 0.5;

    String verdict;
    Color verdictColor;
    if (good) {
      verdict = 'On entry — ready to take.';
      verdictColor = AppColors.bullish;
    } else if (chasing) {
      verdict =
          'Price has moved ${drift.toStringAsFixed(2)}% past entry. Consider waiting for a pullback.';
      verdictColor = AppColors.bearish;
    } else {
      verdict =
          'Price drift ${drift.toStringAsFixed(2)}% — still actionable, watch for entry retest.';
      verdictColor = AppColors.gold;
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.show_chart, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text('Live price', style: tt.titleMedium),
              const Spacer(),
              if (alert.dayChangePct != null)
                Text(
                  '${alert.dayChangePct! >= 0 ? "+" : ""}${alert.dayChangePct!.toStringAsFixed(2)}% today',
                  style: TextStyle(
                    color: alert.dayChangePct! >= 0
                        ? AppColors.bullish
                        : AppColors.bearish,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '\$${now.toStringAsFixed(2)}',
                style: AppTypography.mono(
                  size: 28,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'vs \$${alert.entry.toStringAsFixed(2)} entry',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: verdictColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: verdictColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  good ? Icons.check_circle_outline : Icons.info_outline,
                  color: verdictColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    verdict,
                    style: TextStyle(
                      color: verdictColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "What invalidates this setup" — concrete failure conditions so users
/// know when to give up on the trade. Generic by direction with mode flavour.
class _InvalidationCard extends StatelessWidget {
  const _InvalidationCard({required this.alert});
  final TradeAlert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final bool bull = alert.isBullish;
    final List<String> bullets = <String>[
      if (alert.stop != null)
        bull
            ? 'Price closes below \$${alert.stop!.toStringAsFixed(2)} (stop)'
            : 'Price closes above \$${alert.stop!.toStringAsFixed(2)} (stop)',
      bull
          ? 'Volume drops below 80% of the 20-day average without follow-through'
          : 'Volume drops below 80% of the 20-day average — momentum is fading',
      bull
          ? 'Price extends >2% past entry without you in — the move is late, wait for pullback'
          : 'Price extends >2% past entry on the short side without you in — late entry, wait for retest',
      'A market-wide event (Fed announcement, geopolitical shock) changes the regime — close + reassess',
      if (alert.mode == ScannerMode.day)
        'Setup hasn\'t resolved by 12:30 PM ET — day-trade window is closing',
      if (alert.mode == ScannerMode.swing)
        'Trade hasn\'t reached T1 within 5 sessions — thesis is decaying',
    ];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.cancel_outlined,
                  color: AppColors.bearish, size: 18),
              const SizedBox(width: 8),
              Text('What invalidates this setup', style: tt.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 10),
                    child: Icon(Icons.close,
                        color: AppColors.bearish, size: 12),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
