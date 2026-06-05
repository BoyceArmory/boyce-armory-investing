import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../data/shadow_models.dart';
import '../providers/performance_providers.dart';

/// Scanner Track Record screen — customer-facing view of what every
/// A+ scanner alert WOULD have returned if taken automatically.
///
/// Honest framing throughout: these are SIMULATED outcomes, not real
/// human-taken trades. The hero card labels them as such. The data
/// is real — the backend tracks every alert minute-by-minute against
/// the underlying and closes on stop/target hit or timeout.
class ScannerTrackRecordScreen extends ConsumerStatefulWidget {
  const ScannerTrackRecordScreen({super.key});

  @override
  ConsumerState<ScannerTrackRecordScreen> createState() =>
      _ScannerTrackRecordScreenState();
}

class _ScannerTrackRecordScreenState
    extends ConsumerState<ScannerTrackRecordScreen> {
  int _windowDays = 30;

  void _refreshAll() {
    ref.invalidate(shadowStatsProvider);
    ref.invalidate(shadowRecentProvider);
    ref.invalidate(shadowOpenProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ShadowStats> statsAsync =
        ref.watch(shadowStatsProvider(_windowDays));
    final AsyncValue<List<ShadowTradeRecord>> recentAsync =
        ref.watch(shadowRecentProvider);
    final AsyncValue<List<ShadowTradeRecord>> openAsync =
        ref.watch(shadowOpenProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        elevation: 0,
        titleSpacing: 4,
        title: Row(
          children: <Widget>[
            const Text(
              'SCANNER TRACK RECORD',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'A+ ONLY',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold, size: 22),
            onPressed: _refreshAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.gold.withValues(alpha: 0.15),
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.obsidian,
          onRefresh: () async {
            _refreshAll();
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              const _DisclosureStrip(),
              const SizedBox(height: 14),
              _WindowSelector(
                value: _windowDays,
                onChanged: (int v) => setState(() => _windowDays = v),
              ),
              const SizedBox(height: 16),
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: LoadingIndicator(),
                ),
                error: (Object e, _) => ErrorState(
                  message: 'Could not load track record',
                  details: '$e',
                ),
                data: (ShadowStats stats) => _StatsBody(stats: stats),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Currently Tracking', accent: true),
              const SizedBox(height: 10),
              openAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (Object _, __) => const SizedBox.shrink(),
                data: (List<ShadowTradeRecord> list) =>
                    _OpenList(trades: list),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Recent Closes'),
              const SizedBox(height: 10),
              recentAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (Object _, __) => const SizedBox.shrink(),
                data: (List<ShadowTradeRecord> list) =>
                    _RecentList(trades: list),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DISCLOSURE STRIP — slim, single-line, tappable for full text.
// ============================================================================
class _DisclosureStrip extends StatefulWidget {
  const _DisclosureStrip();
  @override
  State<_DisclosureStrip> createState() => _DisclosureStripState();
}

class _DisclosureStripState extends State<_DisclosureStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  color: AppColors.gold.withValues(alpha: 0.85),
                  size: 14,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Simulated outcomes from A+ alerts.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.gold.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
            if (_expanded) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'The system auto-opens a simulated position on every A+ scanner '
                'alert at the published entry, with the same stops and targets. '
                'Each is tracked minute-by-minute and closed on stop/target hit '
                'or timeout. Numbers below are what the scanner would have '
                'returned if every A+ signal had been taken automatically. '
                'Not financial advice — your actual results vary with execution '
                'and slippage.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WINDOW SELECTOR — premium segmented control with gold underline.
// ============================================================================
class _WindowSelector extends StatelessWidget {
  const _WindowSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<int> options = <int>[7, 30, 90, 180];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: options.map((int days) {
          final bool selected = days == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(days),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: <Color>[
                            Color(0xFFD4AF37),
                            Color(0xFFB8941F),
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${days}D',
                    style: TextStyle(
                      color: selected
                          ? AppColors.obsidian
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// STATS BODY — empty state OR hero + grid + by-mode.
// ============================================================================
class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final ShadowStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.totalTrades == 0) {
      return _EmptyStats();
    }
    return Column(
      children: <Widget>[
        _HeroCard(stats: stats),
        const SizedBox(height: 12),
        _StatGrid(stats: stats),
        if (stats.byMode.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _ByModeCard(stats: stats),
        ],
      ],
    );
  }
}

class _EmptyStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1A1714), Color(0xFF0D0B08)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_empty,
                color: AppColors.gold, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Track record building',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The system tracks every A+ alert from publish to close. '
            'Numbers appear here once trades start closing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO CARD — two-column: big R-multiple total + win rate gauge.
// ============================================================================
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final ShadowStats stats;

  static const Color _green = Color(0xFF8FD89F);
  static const Color _red = Color(0xFFE07A6B);

  @override
  Widget build(BuildContext context) {
    final bool positive = stats.totalRMultiple >= 0;
    final Color rColor = positive ? _green : _red;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1F1A14), Color(0xFF0D0B08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.06),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.trending_up,
                    color: AppColors.gold.withValues(alpha: 0.9), size: 14),
                const SizedBox(width: 6),
                Text(
                  'LAST ${stats.windowDays} DAYS',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const Spacer(),
                if (stats.openTrades > 0)
                  _LiveBadge(count: stats.openTrades),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Big R total
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      RichText(
                        text: TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: positive
                                  ? '+${stats.totalRMultiple.toStringAsFixed(1)}'
                                  : stats.totalRMultiple.toStringAsFixed(1),
                              style: TextStyle(
                                color: rColor,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: 'R',
                              style: TextStyle(
                                color: rColor.withValues(alpha: 0.65),
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TOTAL EDGE',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Win rate ring
                _WinRateRing(winRate: stats.winRate),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _MicroStat(
                  label: 'TRADES',
                  value: '${stats.totalTrades}',
                ),
                const _MicroDivider(),
                _MicroStat(
                  label: 'AVG R',
                  value: '${stats.avgRMultiple >= 0 ? "+" : ""}'
                      '${stats.avgRMultiple.toStringAsFixed(2)}',
                  color: stats.avgRMultiple >= 0 ? _green : _red,
                ),
                const _MicroDivider(),
                _MicroStat(
                  label: 'EXPECTANCY',
                  value: '${stats.expectancyPct >= 0 ? "+" : ""}'
                      '${stats.expectancyPct.toStringAsFixed(2)}%',
                  color: stats.expectancyPct >= 0 ? _green : _red,
                ),
              ],
            ),
            if (stats.spyReturnPct != null) ...<Widget>[
              const SizedBox(height: 14),
              _SpyBenchmark(spyPct: stats.spyReturnPct!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  const _MicroStat({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.7),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroDivider extends StatelessWidget {
  const _MicroDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _WinRateRing extends StatelessWidget {
  const _WinRateRing({required this.winRate});
  final double winRate;

  Color get _ringColor {
    if (winRate >= 60) return const Color(0xFF8FD89F);
    if (winRate >= 45) return AppColors.gold;
    return const Color(0xFFE07A6B);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 86,
            height: 86,
            child: CircularProgressIndicator(
              value: (winRate.clamp(0, 100)) / 100,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(_ringColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${winRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: _ringColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'WIN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3D2A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8FD89F).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF8FD89F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count LIVE',
            style: const TextStyle(
              color: Color(0xFF8FD89F),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpyBenchmark extends StatelessWidget {
  const _SpyBenchmark({required this.spyPct});
  final double spyPct;

  @override
  Widget build(BuildContext context) {
    final bool positive = spyPct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.show_chart,
            color: Colors.white.withValues(alpha: 0.5),
            size: 13,
          ),
          const SizedBox(width: 6),
          Text(
            'vs SPY buy-and-hold',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
            ),
          ),
          const Spacer(),
          Text(
            '${positive ? "+" : ""}${spyPct.toStringAsFixed(2)}%',
            style: TextStyle(
              color: positive
                  ? const Color(0xFF8FD89F)
                  : const Color(0xFFE07A6B),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STAT GRID — 4 polished tiles with colored accents.
// ============================================================================
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final ShadowStats stats;

  static const Color _green = Color(0xFF8FD89F);
  static const Color _red = Color(0xFFE07A6B);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: <Widget>[
        _StatTile(
          label: 'WINNERS',
          value: '${stats.winningTrades}',
          subtitle: '+${stats.avgWinPct.toStringAsFixed(1)}% avg',
          icon: Icons.arrow_upward,
          accent: _green,
        ),
        _StatTile(
          label: 'LOSERS',
          value: '${stats.losingTrades}',
          subtitle: '${stats.avgLossPct.toStringAsFixed(1)}% avg',
          icon: Icons.arrow_downward,
          accent: _red,
        ),
        _StatTile(
          label: 'BEST WIN',
          value: stats.bestTradeSymbol ?? '—',
          subtitle: stats.bestTradePct != null
              ? '+${stats.bestTradePct!.toStringAsFixed(1)}%'
              : '',
          icon: Icons.emoji_events_outlined,
          accent: AppColors.gold,
        ),
        _StatTile(
          label: 'WORST LOSS',
          value: stats.worstTradeSymbol ?? '—',
          subtitle: stats.worstTradePct != null
              ? '${stats.worstTradePct!.toStringAsFixed(1)}%'
              : '',
          icon: Icons.shield_outlined,
          accent: _red,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 12, color: accent.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BY MODE — bar chart of contribution per mode.
// ============================================================================
class _ByModeCard extends StatelessWidget {
  const _ByModeCard({required this.stats});
  final ShadowStats stats;

  static const Color _green = Color(0xFF8FD89F);
  static const Color _red = Color(0xFFE07A6B);

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, ShadowModeStats>> entries =
        stats.byMode.entries.toList()
          ..sort((MapEntry<String, ShadowModeStats> a,
                  MapEntry<String, ShadowModeStats> b) =>
              b.value.totalRMultiple.compareTo(a.value.totalRMultiple));
    final double maxAbs = entries.fold<double>(
      0,
      (double acc, MapEntry<String, ShadowModeStats> e) =>
          e.value.totalRMultiple.abs() > acc
              ? e.value.totalRMultiple.abs()
              : acc,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.bar_chart,
                  color: AppColors.gold.withValues(alpha: 0.9), size: 14),
              const SizedBox(width: 6),
              Text(
                'BY MODE',
                style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final MapEntry<String, ShadowModeStats> e in entries) ...<Widget>[
            _ModeBar(
              mode: e.key,
              modeStats: e.value,
              maxAbs: maxAbs == 0 ? 1 : maxAbs,
              green: _green,
              red: _red,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ModeBar extends StatelessWidget {
  const _ModeBar({
    required this.mode,
    required this.modeStats,
    required this.maxAbs,
    required this.green,
    required this.red,
  });
  final String mode;
  final ShadowModeStats modeStats;
  final double maxAbs;
  final Color green;
  final Color red;

  @override
  Widget build(BuildContext context) {
    final double r = modeStats.totalRMultiple;
    final bool positive = r >= 0;
    final Color barColor = positive ? green : red;
    final double pct = (r.abs() / maxAbs).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            SizedBox(
              width: 60,
              child: Text(
                mode.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${modeStats.totalTrades} trades · ${modeStats.winRate.toStringAsFixed(0)}% win',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11.5,
                ),
              ),
            ),
            Text(
              '${positive ? "+" : ""}${r.toStringAsFixed(1)}R',
              style: TextStyle(
                color: barColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 5,
            color: Colors.white.withValues(alpha: 0.04),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      barColor.withValues(alpha: 0.6),
                      barColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SECTION TITLE — gold heading with optional pulse dot accent.
// ============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.accent = false});
  final String text;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: <Widget>[
          if (accent) ...<Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0xFF8FD89F),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFF8FD89F).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// OPEN LIST — live positions with pulse indicators.
// ============================================================================
class _OpenList extends StatelessWidget {
  const _OpenList({required this.trades});
  final List<ShadowTradeRecord> trades;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF14110D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.pause_circle_outline,
              color: Colors.white.withValues(alpha: 0.4),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              'No live A+ positions right now.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: trades
          .map((ShadowTradeRecord t) => _OpenTile(trade: t))
          .toList(),
    );
  }
}

class _OpenTile extends StatelessWidget {
  const _OpenTile({required this.trade});
  final ShadowTradeRecord trade;

  static const Color _green = Color(0xFF8FD89F);
  static const Color _red = Color(0xFFE07A6B);

  @override
  Widget build(BuildContext context) {
    final bool bull = trade.direction == 'bullish';
    final Color sideColor = bull ? _green : _red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFF14110D),
            const Color(0xFF14110D).withValues(alpha: 0.6),
          ],
        ),
        border: Border(
          left: BorderSide(color: sideColor.withValues(alpha: 0.7), width: 3),
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Text(
            trade.symbol,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: sideColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              bull ? 'LONG' : 'SHORT',
              style: TextStyle(
                color: sideColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${trade.kind.replaceAll('_', ' ').toUpperCase()} · ${trade.mode.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '\$${trade.entry.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'entry',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          _PulseDot(color: _green),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        final double t = _c.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45 + 0.45 * t),
                blurRadius: 4 + 6 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// RECENT LIST — rows with R-multiple bar and color-coded outcomes.
// ============================================================================
class _RecentList extends StatelessWidget {
  const _RecentList({required this.trades});
  final List<ShadowTradeRecord> trades;
  static final DateFormat _df = DateFormat('MMM d');

  static const Color _green = Color(0xFF8FD89F);
  static const Color _red = Color(0xFFE07A6B);

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF14110D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          'No closed A+ shadow trades in the last 60 days yet.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12.5,
          ),
        ),
      );
    }
    // Find max |R| for scaling the bars
    final double maxAbsR = trades.fold<double>(
      0.0,
      (double acc, ShadowTradeRecord t) {
        final double r = (t.rMultiple ?? 0).abs();
        return r > acc ? r : acc;
      },
    );
    return Column(
      children: trades.map((ShadowTradeRecord t) {
        final double r = t.rMultiple ?? 0;
        final double pnl = t.pnlPct ?? 0;
        final bool isWin = t.isWin;
        final bool isLoss = t.isLoss;
        final Color sideColor = isWin
            ? _green
            : isLoss
                ? _red
                : Colors.white.withValues(alpha: 0.5);
        final double barWidth =
            maxAbsR == 0 ? 0 : (r.abs() / maxAbsR).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14110D),
            border: Border(
              left: BorderSide(color: sideColor.withValues(alpha: 0.7), width: 3),
              top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    t.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.direction == 'bullish'
                          ? _green.withValues(alpha: 0.15)
                          : _red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      t.direction == 'bullish' ? 'LONG' : 'SHORT',
                      style: TextStyle(
                        color:
                            t.direction == 'bullish' ? _green : _red,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${t.kind.replaceAll('_', ' ').toUpperCase()} · ${t.mode.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${r >= 0 ? "+" : ""}${r.toStringAsFixed(2)}R',
                        style: TextStyle(
                          color: sideColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${pnl >= 0 ? "+" : ""}${pnl.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // R-multiple magnitude bar centered around zero
              Row(
                children: <Widget>[
                  // left side (losses)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: r < 0
                          ? FractionallySizedBox(
                              widthFactor: barWidth,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(2),
                                  color: _red.withValues(alpha: 0.8),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  // right side (wins)
                  Expanded(
                    child: r >= 0
                        ? FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: barWidth,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: _green.withValues(alpha: 0.8),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.flag_outlined,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.exitReason?.replaceAll('_', ' ') ?? '—',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    t.closedAt != null ? _df.format(t.closedAt!) : '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
