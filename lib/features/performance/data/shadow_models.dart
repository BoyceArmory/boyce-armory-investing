/// Models for the scanner shadow-trading track record.
///
/// Shadow trades are SYNTHETIC positions automatically opened on every
/// A and A+ scanner alert. The backend tracks them minute-by-minute vs
/// the underlying price and closes on stop/target hit or timeout. The
/// closed outcomes power "what every A/A+ alert would have returned"
/// without requiring real human-taken trades.
///
/// Honest framing: these are SIMULATED, not real. The UI surfaces them
/// clearly as such alongside the (separate) real-trades performance.
library;

class ShadowStats {
  ShadowStats({
    required this.windowDays,
    required this.totalTrades,
    required this.openTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.winRate,
    required this.avgWinPct,
    required this.avgLossPct,
    required this.totalRMultiple,
    required this.avgRMultiple,
    required this.expectancyPct,
    required this.bestTradeSymbol,
    required this.bestTradePct,
    required this.worstTradeSymbol,
    required this.worstTradePct,
    required this.byMode,
    required this.updatedAt,
  });

  final int windowDays;
  final int totalTrades;
  final int openTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double avgWinPct;
  final double avgLossPct;
  final double totalRMultiple;
  final double avgRMultiple;
  final double expectancyPct;
  final String? bestTradeSymbol;
  final double? bestTradePct;
  final String? worstTradeSymbol;
  final double? worstTradePct;
  final Map<String, ShadowModeStats> byMode;
  final DateTime? updatedAt;

  static final ShadowStats empty = ShadowStats(
    windowDays: 30,
    totalTrades: 0,
    openTrades: 0,
    winningTrades: 0,
    losingTrades: 0,
    winRate: 0,
    avgWinPct: 0,
    avgLossPct: 0,
    totalRMultiple: 0,
    avgRMultiple: 0,
    expectancyPct: 0,
    bestTradeSymbol: null,
    bestTradePct: null,
    worstTradeSymbol: null,
    worstTradePct: null,
    byMode: const <String, ShadowModeStats>{},
    updatedAt: null,
  );

  factory ShadowStats.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> rawMode =
        (j['byMode'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, ShadowModeStats> byMode = <String, ShadowModeStats>{
      for (final MapEntry<String, dynamic> e in rawMode.entries)
        e.key: ShadowModeStats.fromJson(e.value as Map<String, dynamic>),
    };
    return ShadowStats(
      windowDays: (j['windowDays'] as num?)?.toInt() ?? 30,
      totalTrades: (j['totalTrades'] as num?)?.toInt() ?? 0,
      openTrades: (j['openTrades'] as num?)?.toInt() ?? 0,
      winningTrades: (j['winningTrades'] as num?)?.toInt() ?? 0,
      losingTrades: (j['losingTrades'] as num?)?.toInt() ?? 0,
      winRate: (j['winRate'] as num?)?.toDouble() ?? 0,
      avgWinPct: (j['avgWinPct'] as num?)?.toDouble() ?? 0,
      avgLossPct: (j['avgLossPct'] as num?)?.toDouble() ?? 0,
      totalRMultiple: (j['totalRMultiple'] as num?)?.toDouble() ?? 0,
      avgRMultiple: (j['avgRMultiple'] as num?)?.toDouble() ?? 0,
      expectancyPct: (j['expectancyPct'] as num?)?.toDouble() ?? 0,
      bestTradeSymbol: j['bestTradeSymbol'] as String?,
      bestTradePct: (j['bestTradePct'] as num?)?.toDouble(),
      worstTradeSymbol: j['worstTradeSymbol'] as String?,
      worstTradePct: (j['worstTradePct'] as num?)?.toDouble(),
      byMode: byMode,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }
}

class ShadowModeStats {
  ShadowModeStats({
    required this.totalTrades,
    required this.winRate,
    required this.avgRMultiple,
    required this.totalRMultiple,
  });

  final int totalTrades;
  final double winRate;
  final double avgRMultiple;
  final double totalRMultiple;

  factory ShadowModeStats.fromJson(Map<String, dynamic> j) {
    return ShadowModeStats(
      totalTrades: (j['totalTrades'] as num?)?.toInt() ?? 0,
      winRate: (j['winRate'] as num?)?.toDouble() ?? 0,
      avgRMultiple: (j['avgRMultiple'] as num?)?.toDouble() ?? 0,
      totalRMultiple: (j['totalRMultiple'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ShadowTradeRecord {
  ShadowTradeRecord({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.kind,
    required this.mode,
    required this.grade,
    required this.entry,
    required this.stop,
    required this.exitPrice,
    required this.exitReason,
    required this.pnlPct,
    required this.rMultiple,
    required this.openedAt,
    required this.closedAt,
  });

  final String id;
  final String symbol;
  final String direction;
  final String kind;
  final String mode;
  final String grade;
  final double entry;
  final double stop;
  final double? exitPrice;
  final String? exitReason;
  final double? pnlPct;
  final double? rMultiple;
  final DateTime? openedAt;
  final DateTime? closedAt;

  bool get isWin => (rMultiple ?? 0) > 0.1;
  bool get isLoss => (rMultiple ?? 0) < -0.1;

  factory ShadowTradeRecord.fromJson(Map<String, dynamic> j) {
    return ShadowTradeRecord(
      id: j['id'] as String? ?? '',
      symbol: j['symbol'] as String? ?? '',
      direction: j['direction'] as String? ?? 'bullish',
      kind: j['kind'] as String? ?? '',
      mode: j['mode'] as String? ?? '',
      grade: j['grade'] as String? ?? '',
      entry: (j['entry'] as num?)?.toDouble() ?? 0,
      stop: (j['stop'] as num?)?.toDouble() ?? 0,
      exitPrice: (j['exitPrice'] as num?)?.toDouble(),
      exitReason: j['exitReason'] as String?,
      pnlPct: (j['pnlPct'] as num?)?.toDouble(),
      rMultiple: (j['rMultiple'] as num?)?.toDouble(),
      openedAt: DateTime.tryParse(j['openedAt'] as String? ?? ''),
      closedAt: DateTime.tryParse(j['closedAt'] as String? ?? ''),
    );
  }
}
