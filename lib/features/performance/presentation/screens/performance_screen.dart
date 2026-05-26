import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../data/performance_analytics.dart';
import '../../data/performance_models.dart';
import '../providers/performance_providers.dart';

/// Customer-facing track record / proof-of-concept screen.
///
/// Stream-based — all charts and metrics compute client-side from the live
/// `closed_trades` Firestore stream. The aggregate `/api/performance/`
/// endpoint is used only for the global hero stats fallback when there's
/// no closed-trade data yet (very early in the app's life).
class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  PerfRange _range = PerfRange.allTime;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ClosedTrade>> tradesAsync =
        ref.watch(recentClosedTradesProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: tradesAsync.when(
          loading: () => const Center(child: LoadingIndicator()),
          error: (Object e, _) => ErrorState(
            message: 'Could not load performance',
            details: '$e',
          ),
          data: (List<ClosedTrade> raw) {
            final List<ClosedTrade> filtered = _range.filter(raw);
            final PerfAnalytics a = PerfAnalytics.fromTrades(filtered);
            return _Body(
              all: raw,
              filtered: filtered,
              analytics: a,
              range: _range,
              onRangeChanged: (PerfRange r) => setState(() => _range = r),
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.all,
    required this.filtered,
    required this.analytics,
    required this.range,
    required this.onRangeChanged,
  });

  final List<ClosedTrade> all;
  final List<ClosedTrade> filtered;
  final PerfAnalytics analytics;
  final PerfRange range;
  final ValueChanged<PerfRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: <Widget>[
        const SectionHeader(
          eyebrow: 'Track record',
          title: 'Performance',
        ),
        const SizedBox(height: 16),
        _RangeChips(value: range, onChanged: onRangeChanged),
        const SizedBox(height: 14),
        FadeSlideIn(child: _StatsHero(analytics: analytics)),
        const SizedBox(height: 14),
        if (!analytics.isEmpty) ...<Widget>[
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _EquityCurveCard(analytics: analytics),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 110),
            child: _AdvancedMetricsCard(analytics: analytics),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: _StatsGrid(analytics: analytics),
          ),
          const SizedBox(height: 14),
          if (analytics.monthlyPnl.isNotEmpty) ...<Widget>[
            FadeSlideIn(
              delay: const Duration(milliseconds: 210),
              child: _MonthlyPnlCard(analytics: analytics),
            ),
            const SizedBox(height: 14),
          ],
          if (analytics.bySetup.isNotEmpty) ...<Widget>[
            FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: _SetupBreakdownCard(analytics: analytics),
            ),
            const SizedBox(height: 14),
          ],
          FadeSlideIn(
            delay: const Duration(milliseconds: 310),
            child: _StreaksCard(analytics: analytics),
          ),
          const SizedBox(height: 24),
        ],
        const _TradesSectionHeader(),
        const SizedBox(height: 10),
        _RecentTradesList(trades: filtered),
        const SizedBox(height: 16),
        const _DisclaimerCard(),
      ],
    );
  }
}

// ===========================================================================
//  RANGE CHIPS
// ===========================================================================
class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.value, required this.onChanged});
  final PerfRange value;
  final ValueChanged<PerfRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: PerfRange.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext c, int i) {
          final PerfRange r = PerfRange.values[i];
          final bool selected = r == value;
          return GestureDetector(
            onTap: () => onChanged(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.18)
                    : AppColors.carbon,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : AppColors.steel.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  color: selected ? AppColors.gold : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
//  HERO STATS — Win rate big number + counts
// ===========================================================================
class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final bool empty = analytics.isEmpty;
    final Color winRateColor = empty
        ? AppColors.textSecondary
        : analytics.winRate >= 60
            ? AppColors.bullish
            : analytics.winRate >= 50
                ? AppColors.gold
                : AppColors.bearish;

    return PremiumCard(
      accent: PremiumCardAccent.gold,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'WIN RATE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                empty ? '—' : analytics.winRate.toStringAsFixed(1),
                style: TextStyle(
                  color: winRateColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 56,
                  height: 1.0,
                ),
              ),
              if (!empty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    '%',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const Spacer(),
              if (!empty)
                _PnlPill(value: analytics.cumulativePnlPct),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _MiniStat(label: 'Trades', value: analytics.totalTrades.toString()),
              const SizedBox(width: 18),
              _MiniStat(
                label: 'Wins',
                value: analytics.wins.toString(),
                color: AppColors.bullish,
              ),
              const SizedBox(width: 18),
              _MiniStat(
                label: 'Losses',
                value: analytics.losses.toString(),
                color: AppColors.bearish,
              ),
              if (analytics.breakeven > 0) ...<Widget>[
                const SizedBox(width: 18),
                _MiniStat(label: 'BE', value: analytics.breakeven.toString()),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PnlPill extends StatelessWidget {
  const _PnlPill({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final bool pos = value >= 0;
    final Color color = pos ? AppColors.bullish : AppColors.bearish;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${pos ? "+" : ""}${value.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
//  EQUITY CURVE — line chart, cumulative pnl after each trade
// ===========================================================================
class _EquityCurveCard extends StatelessWidget {
  const _EquityCurveCard({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = <FlSpot>[];
    for (int i = 0; i < analytics.equityCurve.length; i++) {
      spots.add(FlSpot(i.toDouble(), analytics.equityCurve[i]));
    }
    final double minY =
        spots.map((FlSpot s) => s.y).fold<double>(0, (double m, double v) => v < m ? v : m);
    final double maxY = spots
        .map((FlSpot s) => s.y)
        .fold<double>(0, (double m, double v) => v > m ? v : m);
    final double pad = (maxY - minY).abs() * 0.1 + 1;
    final bool pos = analytics.cumulativePnlPct >= 0;
    final Color lineColor = pos ? AppColors.bullish : AppColors.bearish;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'EQUITY CURVE',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                'Cumulative % across ${analytics.totalTrades} trades',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY - pad,
                maxY: maxY + pad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY).abs() / 4).clamp(1, 9999),
                  getDrawingHorizontalLine: (double _) => FlLine(
                    color: AppColors.steel.withValues(alpha: 0.18),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.graphite,
                    tooltipBorder: const BorderSide(color: AppColors.steel),
                    getTooltipItems: (List<LineBarSpot> spots) {
                      return spots.map((LineBarSpot s) {
                        return LineTooltipItem(
                          '${s.y >= 0 ? "+" : ""}${s.y.toStringAsFixed(1)}%',
                          TextStyle(
                            color: lineColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: lineColor,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          lineColor.withValues(alpha: 0.32),
                          lineColor.withValues(alpha: 0.0),
                        ],
                      ),
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

// ===========================================================================
//  ADVANCED METRICS — profit factor, max drawdown, expectancy
// ===========================================================================
class _AdvancedMetricsCard extends StatelessWidget {
  const _AdvancedMetricsCard({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    String pfText;
    if (analytics.profitFactor == double.infinity) {
      pfText = '∞';
    } else if (analytics.profitFactor == 0) {
      pfText = '—';
    } else {
      pfText = analytics.profitFactor.toStringAsFixed(2);
    }
    final Color pfColor = analytics.profitFactor == double.infinity
        ? AppColors.bullish
        : analytics.profitFactor > 1.5
            ? AppColors.bullish
            : analytics.profitFactor > 1.0
                ? AppColors.gold
                : AppColors.bearish;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ADVANCED METRICS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCell(
                  label: 'Profit factor',
                  value: pfText,
                  hint: '>1 is profitable',
                  color: pfColor,
                ),
              ),
              Expanded(
                child: _MetricCell(
                  label: 'Expectancy',
                  value:
                      '${analytics.expectancyPct >= 0 ? "+" : ""}${analytics.expectancyPct.toStringAsFixed(2)}%',
                  hint: 'per trade',
                  color: analytics.expectancyPct >= 0
                      ? AppColors.bullish
                      : AppColors.bearish,
                ),
              ),
              Expanded(
                child: _MetricCell(
                  label: 'Max drawdown',
                  value: '-${analytics.maxDrawdownPct.toStringAsFixed(1)}%',
                  hint: 'peak to trough',
                  color: AppColors.bearish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });
  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
//  STATS GRID — best / worst / avg win / avg loss
// ===========================================================================
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final PerfAnalytics s = analytics;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: 'Best trade',
                value: '+${s.bestTradePct.toStringAsFixed(1)}%',
                sub: s.bestTradeSymbol ?? '',
                color: AppColors.bullish,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Worst trade',
                value: '${s.worstTradePct.toStringAsFixed(1)}%',
                sub: s.worstTradeSymbol ?? '',
                color: AppColors.bearish,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: 'Avg win',
                value: '+${s.avgWinPct.toStringAsFixed(1)}%',
                sub: 'on winning trades',
                color: AppColors.bullish,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                label: 'Avg loss',
                value: '${s.avgLossPct.toStringAsFixed(1)}%',
                sub: 'on losing trades',
                color: AppColors.bearish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  MONTHLY P&L BAR CHART
// ===========================================================================
class _MonthlyPnlCard extends StatelessWidget {
  const _MonthlyPnlCard({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final List<MonthlyPnl> data = analytics.monthlyPnl;
    final double maxAbs = data
        .map((MonthlyPnl m) => m.pnlPct.abs())
        .fold<double>(1, (double a, double b) => a > b ? a : b);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'MONTHLY P&L',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                minY: -maxAbs * 1.2,
                maxY: maxAbs * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (double _) => FlLine(
                    color: AppColors.steel.withValues(alpha: 0.18),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (double v, TitleMeta meta) {
                        final int i = v.toInt();
                        if (i < 0 || i >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final String mk = data[i].monthKey;
                        final String label = mk.length >= 7
                            ? DateFormat.MMM().format(
                                DateTime(int.parse(mk.substring(0, 4)),
                                    int.parse(mk.substring(5, 7))),
                              )
                            : mk;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.graphite,
                    tooltipBorder: const BorderSide(color: AppColors.steel),
                    getTooltipItem: (BarChartGroupData g, int gi,
                        BarChartRodData r, int ri) {
                      final MonthlyPnl m = data[g.x.toInt()];
                      return BarTooltipItem(
                        '${m.pnlPct >= 0 ? "+" : ""}${m.pnlPct.toStringAsFixed(1)}%\n${m.trades} trades',
                        TextStyle(
                          color: m.pnlPct >= 0
                              ? AppColors.bullish
                              : AppColors.bearish,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: data[i].pnlPct,
                          color: data[i].pnlPct >= 0
                              ? AppColors.bullish
                              : AppColors.bearish,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
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

// ===========================================================================
//  SETUP BREAKDOWN — horizontal bars by setup kind
// ===========================================================================
class _SetupBreakdownCard extends StatelessWidget {
  const _SetupBreakdownCard({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final int maxCount = analytics.bySetup
        .map((SetupBreakdown s) => s.count)
        .fold<int>(1, (int a, int b) => a > b ? a : b);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'BY SETUP',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...analytics.bySetup.take(8).map(
                (SetupBreakdown s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SetupRow(item: s, maxCount: maxCount),
                ),
              ),
        ],
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.item, required this.maxCount});
  final SetupBreakdown item;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final double w = (item.count / maxCount).clamp(0.05, 1.0);
    final Color barColor = item.winRate >= 60
        ? AppColors.bullish
        : item.winRate >= 50
            ? AppColors.gold
            : AppColors.bearish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.kind,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${item.winRate.toStringAsFixed(0)}% win  ·  ${item.count}',
              style: TextStyle(
                color: barColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: <Widget>[
              Container(height: 6, color: AppColors.carbon),
              FractionallySizedBox(
                widthFactor: w,
                child: Container(height: 6, color: barColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
//  STREAKS — current + longest win/loss
// ===========================================================================
class _StreaksCard extends StatelessWidget {
  const _StreaksCard({required this.analytics});
  final PerfAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final Color currentColor = analytics.currentStreakIsWin
        ? AppColors.bullish
        : AppColors.bearish;
    final String currentLabel = analytics.currentStreakIsWin ? 'WIN' : 'LOSS';
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'STREAKS',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCell(
                  label: 'Current',
                  value: analytics.currentStreak == 0
                      ? '—'
                      : '${analytics.currentStreak}',
                  hint: '$currentLabel streak',
                  color: currentColor,
                ),
              ),
              Expanded(
                child: _MetricCell(
                  label: 'Longest win',
                  value: analytics.longestWinStreak.toString(),
                  hint: 'consecutive wins',
                  color: AppColors.bullish,
                ),
              ),
              Expanded(
                child: _MetricCell(
                  label: 'Longest loss',
                  value: analytics.longestLossStreak.toString(),
                  hint: 'consecutive losses',
                  color: AppColors.bearish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
//  RECENT TRADES LIST
// ===========================================================================
class _TradesSectionHeader extends StatelessWidget {
  const _TradesSectionHeader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 2),
      child: Text(
        'RECENT TRADES',
        style: TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _RecentTradesList extends StatelessWidget {
  const _RecentTradesList({required this.trades});
  final List<ClosedTrade> trades;

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.show_chart,
          title: 'No closed trades yet',
          message:
              'Once trades close, they show up here with full entry / exit / P&L details.',
        ),
      );
    }
    // Show newest first (Firestore already gives newest first; analytics
    // sorted oldest first for math, but the screen list should be reverse).
    final List<ClosedTrade> sorted = List<ClosedTrade>.from(trades)
      ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
    return Column(
      children: sorted
          .map((ClosedTrade t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TradeRow(trade: t),
              ))
          .toList(growable: false),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.trade});
  final ClosedTrade trade;

  @override
  Widget build(BuildContext context) {
    final bool win = trade.isWin;
    final bool loss = trade.isLoss;
    final Color pnlColor = win
        ? AppColors.bullish
        : loss
            ? AppColors.bearish
            : AppColors.textSecondary;
    final String pnlText = trade.pnlPct == 0
        ? '0.0%'
        : '${trade.pnlPct > 0 ? "+" : ""}${trade.pnlPct.toStringAsFixed(1)}%';
    final String dirLabel = trade.isBullish ? 'CALL' : 'PUT';
    final Color dirColor =
        trade.isBullish ? AppColors.bullish : AppColors.bearish;
    return PremiumCard(
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      trade.symbol,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: dirColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dirLabel,
                        style: TextStyle(
                          color: dirColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  trade.contractLabel ?? DateFormat('MMM d').format(trade.closedAt.toLocal()),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'ENTRY → EXIT',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${trade.entry.toStringAsFixed(2)} → \$${trade.exit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  pnlText,
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  win ? 'WIN' : loss ? 'LOSS' : 'BE',
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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

// ===========================================================================
//  DISCLAIMER
// ===========================================================================
class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();
  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Text(
            'PERFORMANCE DISCLAIMER',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Past performance does not guarantee future results. Numbers shown reflect closed trades only. Boyce Armory is not a registered investment advisor; this is educational content, not personalized investment advice. Options trading involves substantial risk of loss. You can lose more than you invest.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
