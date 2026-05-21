import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/market_context_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../market/presentation/providers/market_providers.dart';

/// Hero "market pulse" card on the home screen. Pulls SPY/QQQ/DIA from
/// /api/market/context.
class MarketPulseCard extends ConsumerWidget {
  const MarketPulseCard({super.key, this.displayName});
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme tt = Theme.of(context).textTheme;
    final String greeting = _greeting();
    final AsyncValue<MarketContext> async = ref.watch(marketContextProvider);

    return PremiumCard(
      accent: PremiumCardAccent.gold,
      glow: true,
      padding: const EdgeInsets.all(22),
      onTap: () => ref.invalidate(marketContextProvider),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -40,
            top: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.gold,
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.obsidian.withValues(alpha: 0.85),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                greeting.toUpperCase(),
                style: tt.labelSmall?.copyWith(color: AppColors.gold),
              ),
              const SizedBox(height: 8),
              Text(
                displayName != null && displayName!.isNotEmpty
                    ? 'Welcome back, ${displayName!.split(' ').first}.'
                    : 'Welcome back.',
                style: tt.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                "Here's what the desk is watching today.",
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 18),
              async.when(
                loading: () => const Row(
                  children: <Widget>[
                    _PulseStat(label: 'SPY', value: '—'),
                    SizedBox(width: 14),
                    _PulseStat(label: 'QQQ', value: '—'),
                    SizedBox(width: 14),
                    _PulseStat(label: 'DIA', value: '—'),
                  ],
                ),
                error: (Object e, _) => const Row(
                  children: <Widget>[
                    _PulseStat(label: 'SPY', value: '—'),
                    SizedBox(width: 14),
                    _PulseStat(label: 'QQQ', value: '—'),
                    SizedBox(width: 14),
                    _PulseStat(label: 'DIA', value: '—'),
                  ],
                ),
                data: (MarketContext ctx) => Row(
                  children: <Widget>[
                    _PulseStat(
                      label: 'SPY',
                      value: ctx.spy != null
                          ? Formatters.priceCompact(ctx.spy!.price)
                          : '—',
                      changePct: ctx.spy?.changePct,
                    ),
                    const SizedBox(width: 14),
                    _PulseStat(
                      label: 'QQQ',
                      value: ctx.qqq != null
                          ? Formatters.priceCompact(ctx.qqq!.price)
                          : '—',
                      changePct: ctx.qqq?.changePct,
                    ),
                    const SizedBox(width: 14),
                    _PulseStat(
                      label: 'DIA',
                      value: ctx.dia != null
                          ? Formatters.priceCompact(ctx.dia!.price)
                          : '—',
                      changePct: ctx.dia?.changePct,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 5) return 'Late night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _PulseStat extends StatelessWidget {
  const _PulseStat({
    required this.label,
    required this.value,
    this.changePct,
  });

  final String label;
  final String value;
  final double? changePct;

  Color get _changeColor {
    if (changePct == null) return AppColors.textTertiary;
    if (changePct! >= 0) return AppColors.bullish;
    return AppColors.bearish;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.mono(size: 15, weight: FontWeight.w700),
        ),
        if (changePct != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            Formatters.signedPercent(changePct, alreadyPercent: true),
            style: AppTypography.mono(
              size: 11,
              weight: FontWeight.w700,
              color: _changeColor,
            ),
          ),
        ],
      ],
    );
  }
}
