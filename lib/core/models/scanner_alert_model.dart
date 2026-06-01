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
    this.stillValid,
    this.lastCheckedPrice,
    this.decayReason,
    this.triggerSnapshot,
    this.backtestExpectancyPct,
    this.backtestAvgWinPct,
    this.backtestAvgLossPct,
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

  /// Set by the backend decay job (`decayCheckJob`, every 5 min during
  /// market hours). When `false`, the card has run past entry/stop, the
  /// underlying price has extended too far, or the original snapshot
  /// turned out to be wrong. UI should hide cards with `stillValid == false`.
  ///
  /// `null` means the decay job hasn't checked yet — treat as still valid.
  final bool? stillValid;

  /// Most recent price the decay job pulled when it re-checked this card.
  /// Useful for showing "Entry $725 → Now $608" in the UI when prices drift.
  final double? lastCheckedPrice;

  /// Human-readable reason the decay job marked this card invalid. Examples:
  ///   "extended"        — price went too far past entry, no longer entryable
  ///   "stopped_out"     — price hit the stop, this trade would have lost
  ///   "target_hit"      — price hit target, this trade would have won
  ///   "snapshot_drift"  — entry price was wrong; differs > 5% from re-check
  final String? decayReason;

  /// Frozen numerical snapshot of the conditions at fire time. Powers the
  /// per-alert "why this fired" panel. Never updated after publish — even a
  /// decayed alert shows what was true when the signal originally fired.
  final TriggerSnapshot? triggerSnapshot;

  /// Measured backtest edge for this (mode, kind), captured at publish time
  /// from setup_stats. `null` if no backtest data exists yet.
  final double? backtestExpectancyPct;
  final double? backtestAvgWinPct;
  final double? backtestAvgLossPct;

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
      stillValid: m['still_valid'] is bool ? m['still_valid'] as bool : null,
      lastCheckedPrice: (m['lastCheckedPrice'] as num?)?.toDouble(),
      decayReason: m['decayReason'] as String?,
      triggerSnapshot: m['triggerSnapshot'] is Map<String, dynamic>
          ? TriggerSnapshot.fromMap(m['triggerSnapshot'] as Map<String, dynamic>)
          : null,
      backtestExpectancyPct:
          (m['backtestExpectancyPct'] as num?)?.toDouble(),
      backtestAvgWinPct: (m['backtestAvgWinPct'] as num?)?.toDouble(),
      backtestAvgLossPct: (m['backtestAvgLossPct'] as num?)?.toDouble(),
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

/// Frozen technical snapshot stamped onto a scanner alert at fire time.
/// Used by the "why this fired" panel. Every field optional because older
/// alerts (pre 2.1.0) won't have this map.
class TriggerSnapshot extends Equatable {
  const TriggerSnapshot({
    this.rsi14,
    this.atr14,
    this.vwap,
    this.vwapDistPct,
    this.ema9,
    this.ema20,
    this.ema50,
    this.adx14,
    this.nr7,
    this.insideBar,
    this.swingHigh50,
    this.swingLow50,
    this.weeklyTrend,
    this.sectorPerfPct,
    this.regime,
  });

  final double? rsi14;
  final double? atr14;
  final double? vwap;
  /// Signed % distance from VWAP: (price - vwap) / vwap * 100.
  final double? vwapDistPct;
  final double? ema9;
  final double? ema20;
  final double? ema50;
  final double? adx14;
  final bool? nr7;
  final bool? insideBar;
  final double? swingHigh50;
  final double? swingLow50;
  final String? weeklyTrend; // up | down | sideways
  /// Sector ETF day change %. Signed.
  final double? sectorPerfPct;
  /// Live regime classification at fire time: bull | bear | chop.
  final String? regime;

  factory TriggerSnapshot.fromMap(Map<String, dynamic> m) => TriggerSnapshot(
        rsi14: (m['rsi14'] as num?)?.toDouble(),
        atr14: (m['atr14'] as num?)?.toDouble(),
        vwap: (m['vwap'] as num?)?.toDouble(),
        vwapDistPct: (m['vwapDistPct'] as num?)?.toDouble(),
        ema9: (m['ema9'] as num?)?.toDouble(),
        ema20: (m['ema20'] as num?)?.toDouble(),
        ema50: (m['ema50'] as num?)?.toDouble(),
        adx14: (m['adx14'] as num?)?.toDouble(),
        nr7: m['nr7'] as bool?,
        insideBar: m['insideBar'] as bool?,
        swingHigh50: (m['swingHigh50'] as num?)?.toDouble(),
        swingLow50: (m['swingLow50'] as num?)?.toDouble(),
        weeklyTrend: m['weeklyTrend'] as String?,
        sectorPerfPct: (m['sectorPerfPct'] as num?)?.toDouble(),
        regime: m['regime'] as String?,
      );

  /// True when ANY field is non-null. Used by UI to decide whether to render
  /// the "why this fired" panel at all (older alerts won't have data).
  bool get hasAnyData =>
      rsi14 != null ||
      atr14 != null ||
      vwap != null ||
      ema9 != null ||
      adx14 != null ||
      nr7 == true ||
      insideBar == true ||
      swingHigh50 != null ||
      swingLow50 != null ||
      sectorPerfPct != null ||
      regime != null;

  @override
  List<Object?> get props => [
        rsi14,
        atr14,
        vwap,
        vwapDistPct,
        ema9,
        ema20,
        ema50,
        adx14,
        nr7,
        insideBar,
        swingHigh50,
        swingLow50,
        weeklyTrend,
        sectorPerfPct,
        regime,
      ];
}
