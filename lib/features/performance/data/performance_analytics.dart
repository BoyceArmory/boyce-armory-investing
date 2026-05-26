import 'performance_models.dart';

/// All-in-one analytics computed client-side from a list of [ClosedTrade]s.
///
/// We keep this pure (no IO, no async) so it's trivial to test and can be
/// invoked any time the underlying stream emits new data.
///
/// Everything here is derived FROM the trades the screen already streams
/// — no extra backend calls.
class PerfAnalytics {
  const PerfAnalytics({
    required this.totalTrades,
    required this.wins,
    required this.losses,
    required this.breakeven,
    required this.winRate,
    required this.avgWinPct,
    required this.avgLossPct,
    required this.bestTradePct,
    required this.worstTradePct,
    required this.bestTradeSymbol,
    required this.worstTradeSymbol,
    required this.cumulativePnlPct,
    required this.profitFactor,
    required this.expectancyPct,
    required this.maxDrawdownPct,
    required this.currentStreak,
    required this.currentStreakIsWin,
    required this.longestWinStreak,
    required this.longestLossStreak,
    required this.equityCurve,
    required this.monthlyPnl,
    required this.bySetup,
  });

  // ---- aggregate counts ----
  final int totalTrades;
  final int wins;
  final int losses;
  final int breakeven;

  // ---- percentages ----
  final double winRate;          // 0-100
  final double avgWinPct;        // average %, e.g. +12.4
  final double avgLossPct;       // average %, e.g. -8.1 (kept negative)
  final double bestTradePct;
  final double worstTradePct;
  final String? bestTradeSymbol;
  final String? worstTradeSymbol;

  // ---- compounded performance ----
  final double cumulativePnlPct; // simple sum, NOT compounded — easier to read
  final double profitFactor;     // sum(wins) / abs(sum(losses)). >1 = profitable
  final double expectancyPct;    // average pnl per trade
  final double maxDrawdownPct;   // largest peak-to-trough drop on equity curve

  // ---- streaks (most recent first) ----
  final int currentStreak;
  final bool currentStreakIsWin;
  final int longestWinStreak;
  final int longestLossStreak;

  // ---- chart data ----
  /// Cumulative pnl after each trade, ORDERED oldest → newest.
  /// Each point is the equity-curve y-value at that trade index.
  final List<double> equityCurve;

  /// Map of monthKey (YYYY-MM) → net % for that month. Sorted oldest → newest.
  final List<MonthlyPnl> monthlyPnl;

  /// Setup-type breakdown sorted by trade count desc.
  final List<SetupBreakdown> bySetup;

  /// Build analytics from a list of closed trades. Trades may arrive
  /// newest-first from Firestore — we sort internally.
  factory PerfAnalytics.fromTrades(List<ClosedTrade> input) {
    if (input.isEmpty) return empty;
    final List<ClosedTrade> trades =
        List<ClosedTrade>.from(input)..sort((a, b) => a.closedAt.compareTo(b.closedAt));

    int wins = 0, losses = 0, be = 0;
    double winSum = 0, lossSum = 0;
    double bestPct = double.negativeInfinity;
    double worstPct = double.infinity;
    String? bestSym;
    String? worstSym;

    final List<double> curve = <double>[];
    double running = 0;

    int currentStreak = 0;
    bool currentStreakIsWin = true;
    int longestWin = 0, longestLoss = 0;

    final Map<String, _MonthAccum> monthAcc = <String, _MonthAccum>{};
    final Map<String, _SetupAccum> setupAcc = <String, _SetupAccum>{};

    for (int i = 0; i < trades.length; i++) {
      final ClosedTrade t = trades[i];
      final double p = t.pnlPct;

      running += p;
      curve.add(running);

      if (t.isWin) {
        wins++;
        winSum += p;
        if (i == 0 || !trades[i - 1].isLoss && !trades[i - 1].isWin) {
          currentStreak = 1;
        } else if (trades[i - 1].isWin) {
          currentStreak++;
        } else {
          currentStreak = 1;
        }
        currentStreakIsWin = true;
        if (currentStreak > longestWin) longestWin = currentStreak;
      } else if (t.isLoss) {
        losses++;
        lossSum += p;
        if (i == 0 || !trades[i - 1].isLoss && !trades[i - 1].isWin) {
          currentStreak = 1;
        } else if (trades[i - 1].isLoss) {
          currentStreak++;
        } else {
          currentStreak = 1;
        }
        currentStreakIsWin = false;
        if (currentStreak > longestLoss) longestLoss = currentStreak;
      } else {
        be++;
      }

      if (p > bestPct) {
        bestPct = p;
        bestSym = t.symbol;
      }
      if (p < worstPct) {
        worstPct = p;
        worstSym = t.symbol;
      }

      // Monthly bucket
      final String mk = _monthKey(t.closedAt);
      monthAcc.putIfAbsent(mk, () => _MonthAccum())
        ..pnl += p
        ..count += 1;

      // Setup bucket — use kind, fall back to "Other"
      final String kind = (t.kind ?? '').trim().isEmpty
          ? 'Other'
          : _humanizeKind(t.kind!);
      setupAcc.putIfAbsent(kind, () => _SetupAccum())
        ..count += 1
        ..pnl += p
        ..wins += t.isWin ? 1 : 0;
    }

    // Max drawdown: walk the equity curve, track running peak, find largest drop.
    double maxDd = 0;
    double peak = curve.isNotEmpty ? curve.first : 0;
    for (final double v in curve) {
      if (v > peak) peak = v;
      final double dd = peak - v;
      if (dd > maxDd) maxDd = dd;
    }

    final int total = trades.length;
    final double winRate = total == 0 ? 0 : (wins / total) * 100.0;
    final double avgWin = wins == 0 ? 0 : winSum / wins;
    final double avgLoss = losses == 0 ? 0 : lossSum / losses;
    final double profitFactor = lossSum == 0
        ? (winSum > 0 ? double.infinity : 0)
        : winSum / lossSum.abs();
    final double expectancy = total == 0 ? 0 : running / total;

    // Sort months oldest → newest
    final List<MonthlyPnl> monthly = monthAcc.entries
        .map((MapEntry<String, _MonthAccum> e) =>
            MonthlyPnl(monthKey: e.key, pnlPct: e.value.pnl, trades: e.value.count))
        .toList()
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));

    // Sort setups by count desc
    final List<SetupBreakdown> bySetup = setupAcc.entries
        .map((MapEntry<String, _SetupAccum> e) => SetupBreakdown(
              kind: e.key,
              count: e.value.count,
              winRate: e.value.count == 0
                  ? 0
                  : (e.value.wins / e.value.count) * 100,
              avgPnlPct: e.value.count == 0 ? 0 : e.value.pnl / e.value.count,
            ))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return PerfAnalytics(
      totalTrades: total,
      wins: wins,
      losses: losses,
      breakeven: be,
      winRate: winRate,
      avgWinPct: avgWin,
      avgLossPct: avgLoss,
      bestTradePct: bestPct == double.negativeInfinity ? 0 : bestPct,
      worstTradePct: worstPct == double.infinity ? 0 : worstPct,
      bestTradeSymbol: bestSym,
      worstTradeSymbol: worstSym,
      cumulativePnlPct: running,
      profitFactor: profitFactor,
      expectancyPct: expectancy,
      maxDrawdownPct: maxDd,
      currentStreak: currentStreak,
      currentStreakIsWin: currentStreakIsWin,
      longestWinStreak: longestWin,
      longestLossStreak: longestLoss,
      equityCurve: curve,
      monthlyPnl: monthly,
      bySetup: bySetup,
    );
  }

  static const PerfAnalytics empty = PerfAnalytics(
    totalTrades: 0,
    wins: 0,
    losses: 0,
    breakeven: 0,
    winRate: 0,
    avgWinPct: 0,
    avgLossPct: 0,
    bestTradePct: 0,
    worstTradePct: 0,
    bestTradeSymbol: null,
    worstTradeSymbol: null,
    cumulativePnlPct: 0,
    profitFactor: 0,
    expectancyPct: 0,
    maxDrawdownPct: 0,
    currentStreak: 0,
    currentStreakIsWin: true,
    longestWinStreak: 0,
    longestLossStreak: 0,
    equityCurve: <double>[],
    monthlyPnl: <MonthlyPnl>[],
    bySetup: <SetupBreakdown>[],
  );

  bool get isEmpty => totalTrades == 0;
}

class MonthlyPnl {
  const MonthlyPnl({
    required this.monthKey,
    required this.pnlPct,
    required this.trades,
  });
  final String monthKey;
  final double pnlPct;
  final int trades;
}

class SetupBreakdown {
  const SetupBreakdown({
    required this.kind,
    required this.count,
    required this.winRate,
    required this.avgPnlPct,
  });
  final String kind;
  final int count;
  final double winRate;
  final double avgPnlPct;
}

class _MonthAccum {
  double pnl = 0;
  int count = 0;
}

class _SetupAccum {
  int count = 0;
  int wins = 0;
  double pnl = 0;
}

String _monthKey(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

String _humanizeKind(String raw) {
  // 'bull_flag' → 'Bull Flag'
  return raw
      .split(RegExp(r'[_\s]'))
      .where((String s) => s.isNotEmpty)
      .map((String s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
      .join(' ');
}

/// Filter trades by a time-range preset.
enum PerfRange { allTime, ytd, last30Days, last7Days }

extension PerfRangeFilter on PerfRange {
  String get label {
    switch (this) {
      case PerfRange.allTime:
        return 'All time';
      case PerfRange.ytd:
        return 'YTD';
      case PerfRange.last30Days:
        return '30 days';
      case PerfRange.last7Days:
        return '7 days';
    }
  }

  List<ClosedTrade> filter(List<ClosedTrade> trades) {
    final DateTime now = DateTime.now();
    DateTime cutoff;
    switch (this) {
      case PerfRange.allTime:
        return trades;
      case PerfRange.ytd:
        cutoff = DateTime(now.year, 1, 1);
        break;
      case PerfRange.last30Days:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case PerfRange.last7Days:
        cutoff = now.subtract(const Duration(days: 7));
        break;
    }
    return trades
        .where((ClosedTrade t) => t.closedAt.isAfter(cutoff))
        .toList(growable: false);
  }
}
