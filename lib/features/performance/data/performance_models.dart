import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Mirrors PerformanceStats from the backend (src/types/trade.types.ts).
class PerformanceStats extends Equatable {
  const PerformanceStats({
    required this.totalAlerts,
    required this.totalTrades,
    required this.winningTrades,
    required this.losingTrades,
    required this.breakevenTrades,
    required this.winRate,
    required this.avgGainPct,
    required this.avgLossPct,
    required this.bestTradePct,
    required this.worstTradePct,
    this.bestTradeSymbol,
    this.worstTradeSymbol,
    this.updatedAt,
  });

  final int totalAlerts;
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final int breakevenTrades;
  final double winRate;
  final double avgGainPct;
  final double avgLossPct;
  final double bestTradePct;
  final double worstTradePct;
  final String? bestTradeSymbol;
  final String? worstTradeSymbol;
  final String? updatedAt;

  factory PerformanceStats.fromJson(Map<String, dynamic> j) {
    double n(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    int ni(Object? v) =>
        v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return PerformanceStats(
      totalAlerts: ni(j['totalAlerts']),
      totalTrades: ni(j['totalTrades']),
      winningTrades: ni(j['winningTrades']),
      losingTrades: ni(j['losingTrades']),
      breakevenTrades: ni(j['breakevenTrades']),
      winRate: n(j['winRate']),
      avgGainPct: n(j['avgGainPct']),
      avgLossPct: n(j['avgLossPct']),
      bestTradePct: n(j['bestTradePct']),
      worstTradePct: n(j['worstTradePct']),
      bestTradeSymbol: j['bestTradeSymbol'] as String?,
      worstTradeSymbol: j['worstTradeSymbol'] as String?,
      updatedAt: j['updatedAt'] as String?,
    );
  }

  /// Empty stats — shown when the backend has no data yet (e.g. fresh launch).
  static const PerformanceStats empty = PerformanceStats(
    totalAlerts: 0,
    totalTrades: 0,
    winningTrades: 0,
    losingTrades: 0,
    breakevenTrades: 0,
    winRate: 0,
    avgGainPct: 0,
    avgLossPct: 0,
    bestTradePct: 0,
    worstTradePct: 0,
  );

  @override
  List<Object?> get props => <Object?>[
        totalAlerts,
        totalTrades,
        winningTrades,
        losingTrades,
        breakevenTrades,
        winRate,
        avgGainPct,
        avgLossPct,
        bestTradePct,
        worstTradePct,
        bestTradeSymbol,
        worstTradeSymbol,
        updatedAt,
      ];
}

/// Mirrors a closed trade from Firestore `closed_trades` collection.
class ClosedTrade extends Equatable {
  const ClosedTrade({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.entry,
    required this.exit,
    required this.result,
    required this.pnlPct,
    required this.closedAt,
    this.kind,
    this.mode,
    this.contractLabel,
    this.source,
  });

  final String id;
  final String symbol;
  final String direction;
  final double entry;
  final double exit;
  final String result; // "win" | "loss" | "breakeven"
  final double pnlPct;
  final DateTime closedAt;
  final String? kind;
  final String? mode;
  final String? contractLabel;

  /// Origin of the closed trade. 'shadow' = scanner-tracked simulated outcome
  /// (auto-opened on every A/A+ alert). Anything else (typically 'real' or
  /// null) is a real human-taken trade closed by an admin via the trade
  /// management surface. The Performance screen splits these into two tabs:
  /// user trades on "My Trades", shadow trades on "Scanner Track Record".
  final String? source;

  bool get isShadow => source == 'shadow';
  bool get isUserTrade => !isShadow;

  bool get isWin => result == 'win';
  bool get isLoss => result == 'loss';
  bool get isBullish => direction == 'bullish';

  factory ClosedTrade.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> m = doc.data();
    double n(Object? v) =>
        v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    final Object? closedRaw = m['closedAt'];
    DateTime closedAt;
    if (closedRaw is Timestamp) {
      closedAt = closedRaw.toDate();
    } else if (closedRaw is String) {
      closedAt = DateTime.tryParse(closedRaw) ?? DateTime.now();
    } else {
      closedAt = DateTime.now();
    }

    // Build a short contract label like "145C 4/19" for display, if data
    // is present. Falls back to null when no contract attached (stock trade).
    String? contract;
    final Object? c = m['contract'];
    if (c is Map<String, dynamic>) {
      final String type = (c['type'] ?? '').toString().toUpperCase();
      final num? strike = c['strike'] as num?;
      final String? exp = c['expiry'] as String?;
      if (strike != null && exp != null && exp.isNotEmpty) {
        final String exShort = exp.length >= 10
            ? '${exp.substring(5, 7)}/${exp.substring(8, 10)}'
            : exp;
        contract =
            '${strike.toStringAsFixed(0)}${type.startsWith('C') ? 'C' : 'P'} $exShort';
      }
    }

    return ClosedTrade(
      id: doc.id,
      symbol: (m['symbol'] ?? '').toString(),
      direction: (m['direction'] ?? 'bullish').toString(),
      entry: n(m['entry']),
      exit: n(m['exit']),
      result: (m['result'] ?? 'breakeven').toString(),
      pnlPct: n(m['pnlPct']),
      closedAt: closedAt,
      kind: m['kind'] as String?,
      mode: m['mode'] as String?,
      contractLabel: contract,
      source: m['source'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        symbol,
        direction,
        entry,
        exit,
        result,
        pnlPct,
        closedAt,
        kind,
        mode,
        contractLabel,
        source,
      ];
}
