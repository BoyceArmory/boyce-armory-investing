import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';

/// SPY / QQQ / DIA card. Auto-refreshes every 30s via the home overview
/// stream. Tap to force-refresh.
class MarketPulseCard extends ConsumerWidget {
  const MarketPulseCard({
    super.key,
    this.displayName,
  });

  final String? displayName;

  static const String _backgroundPath =
      'assets/backgrounds/blank_backgrounds.png';

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final AsyncValue<HomeOverview> async =
        ref.watch(homeOverviewStreamProvider);

    return GestureDetector(
      onTap: () => ref.invalidate(homeOverviewStreamProvider),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: double.infinity,
          height: 230,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withOpacity(0.22),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Image.asset(
                    _backgroundPath,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.12),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.45),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
  horizontal: 18,
),
                    child: async.when(
                      loading: () => const _PulseStatRow.empty(),
                      error: (
                        Object error,
                        StackTrace stackTrace,
                      ) =>
                          const _PulseStatRow.empty(),
                      data: (HomeOverview ov) =>
                          _PulseStatRow.fromOverview(ov),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseStatRow extends StatelessWidget {
  const _PulseStatRow({
    required this.stats,
  });

  const _PulseStatRow.empty()
      : stats = const <_PulseStatData>[
          _PulseStatData(
            label: 'SPY',
            value: '—',
          ),
          _PulseStatData(
            label: 'QQQ',
            value: '—',
          ),
          _PulseStatData(
            label: 'DIA',
            value: '—',
          ),
        ];

  /// Pick SPY, QQQ, DIA out of the overview's indices list.
  factory _PulseStatRow.fromOverview(HomeOverview ov) {
    MiniQuote? pick(String sym) {
      for (final q in ov.indices) {
        if (q.symbol == sym) return q;
      }
      return null;
    }

    _PulseStatData stat(String label) {
      final q = pick(label);
      return _PulseStatData(
        label: label,
        value: q != null ? Formatters.priceCompact(q.price) : '—',
        changePct: q?.changePct,
      );
    }

    return _PulseStatRow(
      stats: <_PulseStatData>[
        stat('SPY'),
        stat('QQQ'),
        stat('DIA'),
      ],
    );
  }

  final List<_PulseStatData> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stats
          .map(
            (_PulseStatData stat) => Expanded(
              child: _PulseStat(
                label: stat.label,
                value: stat.value,
                changePct: stat.changePct,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PulseStatData {
  const _PulseStatData({
    required this.label,
    required this.value,
    this.changePct,
  });

  final String label;
  final String value;
  final double? changePct;
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
    if (changePct == null) {
      return AppColors.textTertiary;
    }

    if (changePct! >= 0) {
      return AppColors.bullish;
    }

    return AppColors.bearish;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 1.2,
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.black.withOpacity(0.95),
                    blurRadius: 8,
                  ),
                ],
              ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppTypography.mono(
            size: 20,
            weight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        if (changePct != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            Formatters.signedPercent(
              changePct,
              alreadyPercent: true,
            ),
            textAlign: TextAlign.center,
            style: AppTypography.mono(
              size: 14,
              weight: FontWeight.w900,
              color: _changeColor,
            ),
          ),
        ],
      ],
    );
  }
}