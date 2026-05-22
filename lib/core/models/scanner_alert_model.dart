import 'package:equatable/equatable.dart';
import 'enums.dart';
import 'option_contract_model.dart';

/// Mirror of the `scanner_alerts` Firestore doc (the public view that users
/// see). `scanner_results` (admin-only) shares the same shape.
class ScannerAlert extends Equatable {
  const ScannerAlert({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.kind,
    required this.reason,
    required this.score,
    required this.grade,
    required this.visibility,
    required this.promoted,
    required this.createdAt,
    this.entry,
    this.target,
    this.stop,
    this.target1,
    this.target2,
    this.target3,
    this.riskReward,
    this.session,
    this.relVolume,
    this.histWinRate,
    this.histSampleSize,
    this.whyThisStock,
    this.family,
    this.dataSource,
    this.preConfirm = false,
    this.asOf,
    this.suggestedContract,
    this.currentPrice,
    this.volume,
    this.dayChangePct,
    this.mode = ScannerMode.swing,
  });

  final String id;
  final String symbol;
  final SetupDirection direction;
  final String kind;            // 'breakout' | 'bull_flag' | ...
  final String reason;
  final int score;              // 0-100
  final SetupGrade grade;
  final AlertVisibility visibility;
  final bool promoted;
  final DateTime createdAt;
  final double? entry;
  final double? target;
  final double? stop;

  /// Scaled-exit ladder. T1=1R, T2=2R, T3=3R (R = entry-to-stop distance).
  /// Scale 1/3 of position at each. `target` (above) equals `target2` so the
  /// older UI keeps working without changes.
  final double? target1;
  final double? target2;
  final double? target3;
  /// Reward-to-risk ratio measured to T2 (typically 2.0).
  final double? riskReward;

  /// Market session at scan time: premarket / open / morning / lunch /
  /// afternoon / close / closed. Useful for time-of-day labelling.
  final String? session;

  /// Relative volume — current bar vs 20-bar average. >1 = above average.
  final double? relVolume;

  /// Historical win rate (0–100) for this (mode, kind) over the rolling
  /// closed-trades window. Only set when we have ≥5 closed trades.
  final double? histWinRate;

  /// Sample size behind `histWinRate`. UI should hide the badge if < 5.
  final int? histSampleSize;

  /// Per-alert narrative explaining why THIS specific ticker is firing right
  /// now — generated server-side from the snapshot. The Flutter card uses
  /// this for the "Why this stock" section instead of the terse `reason`.
  final String? whyThisStock;

  /// Strategy family: breakout / breakdown / mean_reversion / momentum /
  /// reversal. Computed server-side from `kind`. Lets future UI group/filter
  /// setups by family.
  final String? family;

  /// Which provider served the snapshot. Audit only.
  final String? dataSource;

  /// True when this is a "forming" alert — score is below the public floor
  /// but within striking distance. Always admin_only.
  final bool preConfirm;

  final DateTime? asOf;
  final OptionContract? suggestedContract;

  /// Latest stock price at scan time. Optional - backend may not always send.
  final double? currentPrice;

  /// Latest session volume.
  final int? volume;

  /// Day percent change (signed). Optional.
  final double? dayChangePct;

  /// Which scanner mode produced this signal.
  final ScannerMode mode;

  bool get isBullish => direction == SetupDirection.bullish;

  double? get riskRewardRatio {
    if (entry == null || target == null || stop == null) return null;
    final double reward = (target! - entry!).abs();
    final double risk = (entry! - stop!).abs();
    if (risk == 0) return null;
    return reward / risk;
  }

  /// Percent move from entry to target (signed by direction).
  double? get targetMovePct {
    if (entry == null || target == null || entry == 0) return null;
    final double raw = (target! - entry!) / entry!;
    return isBullish ? raw * 100 : -raw * 100;
  }

  factory ScannerAlert.fromMap(String id, Map<String, dynamic> m) {
    final dynamic contract = m['suggestedContract'];
    return ScannerAlert(
      id: id,
      symbol: (m['symbol'] ?? '') as String,
      direction: SetupDirectionX.fromWire(m['direction'] as String?),
      kind: (m['kind'] ?? '') as String,
      reason: (m['reason'] ?? '') as String,
      score: (m['score'] as num?)?.toInt() ?? 0,
      grade: SetupGradeX.fromWire(m['grade'] as String?),
      visibility: AlertVisibilityX.fromWire(m['visibility'] as String?),
      promoted: (m['promoted'] as bool?) ?? false,
      createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      entry: (m['entry'] as num?)?.toDouble(),
      target: (m['target'] as num?)?.toDouble(),
      stop: (m['stop'] as num?)?.toDouble(),
      target1: (m['target1'] as num?)?.toDouble(),
      target2: (m['target2'] as num?)?.toDouble(),
      target3: (m['target3'] as num?)?.toDouble(),
      riskReward: (m['riskReward'] as num?)?.toDouble(),
      session: m['session'] as String?,
      relVolume: (m['relVolume'] as num?)?.toDouble(),
      histWinRate: (m['histWinRate'] as num?)?.toDouble(),
      histSampleSize: (m['histSampleSize'] as num?)?.toInt(),
      whyThisStock: m['whyThisStock'] as String?,
      family: m['family'] as String?,
      dataSource: m['dataSource'] as String?,
      preConfirm: (m['preConfirm'] as bool?) ?? false,
      asOf: _parseDate(m['asOf']),
      suggestedContract: contract is Map<String, dynamic>
          ? OptionContract.fromMap(contract)
          : null,
      currentPrice: (m['currentPrice'] as num?)?.toDouble() ??
          (m['price'] as num?)?.toDouble(),
      volume: (m['volume'] as num?)?.toInt(),
      dayChangePct: (m['dayChangePct'] as num?)?.toDouble() ??
          (m['changePct'] as num?)?.toDouble(),
      mode: ScannerModeX.fromWire(m['mode'] as String?),
    );
  }

  @override
  List<Object?> get props => [
        id,
        symbol,
        direction,
        kind,
        reason,
        score,
        grade,
        visibility,
        promoted,
        createdAt,
        entry,
        target,
        stop,
        asOf,
        suggestedContract,
        currentPrice,
        volume,
        dayChangePct,
        mode,
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
