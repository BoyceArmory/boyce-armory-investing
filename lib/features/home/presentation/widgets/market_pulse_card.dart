import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';
import '../../../../core/errors/swallowed_error.dart';

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
                // Market session badge top-right: LIVE / PRE-MARKET /
                // AFTER-HOURS / CLOSED. Tells users whether the SPY/QQQ/DIA
                // values are real-time or last-close. Always rendered so the
                // card never looks empty on weekends or overnight.
                Positioned(
                  top: 12,
                  right: 14,
                  child: async.when(
                    loading: () => const SizedBox.shrink(),
                    error: (Object e, StackTrace s) => swallowError(e, s, where: 'home.market_pulse'),
                    data: (HomeOverview ov) =>
                        _SessionBadge(status: ov.marketStatus),
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

class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.status});
  final MarketStatus status;

  Color get _color {
    switch (status) {
      case MarketStatus.live:
        return AppColors.bullish;
      case MarketStatus.pre:
      case MarketStatus.post:
        return AppColors.gold;
      case MarketStatus.closed:
        return AppColors.textSecondary;
    }
  }

  IconData get _icon {
    switch (status) {
      case MarketStatus.live:
        return Icons.circle;
      case MarketStatus.pre:
        return Icons.wb_twilight;
      case MarketStatus.post:
        return Icons.nights_stay_outlined;
      case MarketStatus.closed:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.7), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_icon, size: 9, color: _color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: _color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
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