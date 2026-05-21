import 'package:equatable/equatable.dart';

/// Mirror of `performance_stats/{id}`. Doc id "global" holds aggregate stats;
/// "YYYY-MM" docs hold monthly stats.
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
    required this.updatedAt,
    this.bestTradeSymbol,
    this.worstTradeSymbol,
    this.monthKey,
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
  final DateTime updatedAt;
  final String? bestTradeSymbol;
  final String? worstTradeSymbol;
  final String? monthKey;

  factory PerformanceStats.fromMap(Map<String, dynamic> m) {
    return PerformanceStats(
      totalAlerts: (m['totalAlerts'] as num?)?.toInt() ?? 0,
      totalTrades: (m['totalTrades'] as num?)?.toInt() ?? 0,
      winningTrades: (m['winningTrades'] as num?)?.toInt() ?? 0,
      losingTrades: (m['losingTrades'] as num?)?.toInt() ?? 0,
      breakevenTrades: (m['breakevenTrades'] as num?)?.toInt() ?? 0,
      winRate: (m['winRate'] as num?)?.toDouble() ?? 0,
      avgGainPct: (m['avgGainPct'] as num?)?.toDouble() ?? 0,
      avgLossPct: (m['avgLossPct'] as num?)?.toDouble() ?? 0,
      bestTradePct: (m['bestTradePct'] as num?)?.toDouble() ?? 0,
      worstTradePct: (m['worstTradePct'] as num?)?.toDouble() ?? 0,
      updatedAt: _parseDate(m['updatedAt']) ?? DateTime.now(),
      bestTradeSymbol: m['bestTradeSymbol'] as String?,
      worstTradeSymbol: m['worstTradeSymbol'] as String?,
      monthKey: m['monthKey'] as String?,
    );
  }

  @override
  List<Object?> get props => [
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
        updatedAt,
        bestTradeSymbol,
        worstTradeSymbol,
        monthKey,
      ];
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  try {
    final dynamic d = raw;
    return d.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
