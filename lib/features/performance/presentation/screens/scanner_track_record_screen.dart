import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../data/shadow_models.dart';
import '../providers/performance_providers.dart';

/// Scanner Track Record screen — customer-facing view of what every
/// A and A+ scanner alert WOULD have returned if taken automatically.
///
/// Honest framing throughout: these are SIMULATED outcomes, not real
/// human-taken trades. The hero card labels them as such. The data
/// is real — the backend tracks every alert minute-by-minute against
/// the underlying and closes on stop/target hit or timeout.
///
/// This is the "proof of concept" for what the scanner could do for
/// a customer who took every signal mechanically. Run by the system
/// 24/7 with no human intervention.
class ScannerTrackRecordScreen extends ConsumerStatefulWidget {
  const ScannerTrackRecordScreen({super.key});

  @override
  ConsumerState<ScannerTrackRecordScreen> createState() =>
      _ScannerTrackRecordScreenState();
}

class _ScannerTrackRecordScreenState
    extends ConsumerState<ScannerTrackRecordScreen> {
  int _windowDays = 30;

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
        title: const Text(
          'SCANNER TRACK RECORD',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.gold,
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.gold),
            onPressed: () {
              ref.invalidate(shadowStatsProvider);
              ref.invalidate(shadowRecentProvider);
              ref.invalidate(shadowOpenProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.obsidian,
          onRefresh: () async {
            ref.invalidate(shadowStatsProvider);
            ref.invalidate(shadowRecentProvider);
            ref.invalidate(shadowOpenProvider);
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              _DisclosureBanner(),
              const SizedBox(height: 16),
              _WindowSelector(
                value: _windowDays,
                onChanged: (int v) => setState(() => _windowDays = v),
              ),
              const SizedBox(height: 16),
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingIndicator(),
                ),
                error: (Object e, _) => ErrorState(
                  message: 'Could not load track record',
                  details: '$e',
                ),
                data: (ShadowStats stats) => _StatsBody(stats: stats),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Currently Tracking'),
              const SizedBox(height: 8),
              openAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (Object _, __) => const SizedBox.shrink(),
                data: (List<ShadowTradeRecord> list) =>
                    _OpenList(trades: list),
              ),
              const SizedBox(height: 24),
              _SectionTitle('Recent Closes'),
              const SizedBox(height: 8),
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

class _DisclosureBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1714),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'AUTO-TRACKED · SIMULATED',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Every A and A+ scanner alert is auto-opened as a simulated '
                  'position at the published entry, with the same stops and '
                  'targets. The system tracks each one minute-by-minute and '
                  'closes on stop/target hit or timeout. Results below are '
                  'what the scanner would have returned if every signal had '
                  'been taken automatically. Not financial advice — your '
                  'actual results would vary based on execution and slippage.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.4,
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

class _WindowSelector extends StatelessWidget {
  const _WindowSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<int> options = <int>[7, 30, 90, 180];
    return Row(
      children: options.map((int days) {
        final bool selected = days == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(days),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.gold : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '${days}D',
                  style: TextStyle(
                    color: selected ? AppColors.obsidian : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final ShadowStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.totalTrades == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF14110D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            const Icon(Icons.hourglass_empty,
                color: AppColors.gold, size: 32),
            const SizedBox(height: 12),
            const Text(
              'No closed shadow trades yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The system needs A/A+ alerts to fire, then track them to '
              'completion. Check back after the next trading session.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        _HeroCard(stats: stats),
        const SizedBox(height: 14),
        _StatGrid(stats: stats),
        if (stats.byMode.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _ByModeCard(stats: stats),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final ShadowStats stats;

  @override
  Widget build(BuildContext context) {
    final bool positiveR = stats.totalRMultiple > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1A1714), Color(0xFF0D0B08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'LAST ${stats.windowDays} DAYS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                positiveR
                    ? '+${stats.totalRMultiple.toStringAsFixed(1)}R'
                    : '${stats.totalRMultiple.toStringAsFixed(1)}R',
                style: TextStyle(
                  color: positiveR ? const Color(0xFF8FD89F) : const Color(0xFFE07A6B),
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TOTAL EDGE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.totalTrades} trades · ${stats.winRate.toStringAsFixed(0)}% win rate · '
            '${stats.avgRMultiple >= 0 ? "+" : ""}${stats.avgRMultiple.toStringAsFixed(2)}R avg',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final ShadowStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: <Widget>[
        _StatTile(
          label: 'WINNERS',
          value: '${stats.winningTrades}',
          subtitle: '+${stats.avgWinPct.toStringAsFixed(1)}% avg',
        ),
        _StatTile(
          label: 'LOSERS',
          value: '${stats.losingTrades}',
          subtitle: '${stats.avgLossPct.toStringAsFixed(1)}% avg',
        ),
        _StatTile(
          label: 'BEST',
          value: stats.bestTradeSymbol ?? '—',
          subtitle: stats.bestTradePct != null
              ? '+${stats.bestTradePct!.toStringAsFixed(1)}%'
              : '',
        ),
        _StatTile(
          label: 'OPEN NOW',
          value: '${stats.openTrades}',
          subtitle: 'live tracking',
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
  });
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ByModeCard extends StatelessWidget {
  const _ByModeCard({required this.stats});
  final ShadowStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'BY MODE',
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...stats.byMode.entries.map(
            (MapEntry<String, ShadowModeStats> e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 70,
                    child: Text(
                      e.key.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${e.value.totalTrades} trades · ${e.value.winRate.toStringAsFixed(0)}% win',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${e.value.totalRMultiple >= 0 ? "+" : ""}'
                    '${e.value.totalRMultiple.toStringAsFixed(1)}R',
                    style: TextStyle(
                      color: e.value.totalRMultiple >= 0
                          ? const Color(0xFF8FD89F)
                          : const Color(0xFFE07A6B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: AppColors.gold.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _OpenList extends StatelessWidget {
  const _OpenList({required this.trades});
  final List<ShadowTradeRecord> trades;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No live shadow positions right now.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: trade.direction == 'bullish'
                  ? const Color(0xFF1A3D2A)
                  : const Color(0xFF3D1A1A),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trade.symbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  trade.kind.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${trade.mode.toUpperCase()} · ${trade.grade} · entry \$${trade.entry.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.circle, color: AppColors.gold, size: 8),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.trades});
  final List<ShadowTradeRecord> trades;
  static final DateFormat _df = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No closed shadow trades in the last 60 days yet.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      );
    }
    return Column(
      children: trades.map(
        (ShadowTradeRecord t) {
          final double r = t.rMultiple ?? 0;
          final double pnl = t.pnlPct ?? 0;
          final bool isWin = t.isWin;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF14110D),
              border: Border.all(
                color: isWin
                    ? const Color(0xFF8FD89F).withValues(alpha: 0.3)
                    : t.isLoss
                        ? const Color(0xFFE07A6B).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.direction == 'bullish'
                        ? const Color(0xFF1A3D2A)
                        : const Color(0xFF3D1A1A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${t.kind.toUpperCase()} · ${t.mode.toUpperCase()}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${t.exitReason ?? "—"} · ${t.closedAt != null ? _df.format(t.closedAt!) : ""}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${r >= 0 ? "+" : ""}${r.toStringAsFixed(2)}R',
                      style: TextStyle(
                        color: isWin
                            ? const Color(0xFF8FD89F)
                            : t.isLoss
                                ? const Color(0xFFE07A6B)
                                : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${pnl >= 0 ? "+" : ""}${pnl.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }
}
