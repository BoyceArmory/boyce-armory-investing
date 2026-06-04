import 'package:equatable/equatable.dart';

/// Suggested option contract attached to a scanner alert.
///
/// June 2026 expansion: when Polygon Options Advanced is active backend-side,
/// the bid/ask/mid + greeks + IV + spread fields are populated with real
/// chain data instead of math estimates. When disabled, only the basic
/// fields (symbol/strike/expiration/type) are reliable.
class OptionContract extends Equatable {
  const OptionContract({
    required this.symbol,
    required this.underlying,
    required this.strike,
    required this.expiration,
    required this.type,
    this.bid,
    this.ask,
    this.mid,
    this.last,
    this.volume,
    this.openInterest,
    this.iv,
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.spreadPct,
    this.dte,
    this.volOiRatio,
    this.premiumPct,
    this.ivRank,
    this.ivPercentile,
    this.isZeroDte,
    this.earningsBeforeExpiry,
  });

  final String symbol;
  final String underlying;
  final double strike;
  final String expiration; // YYYY-MM-DD
  final String type;       // 'call' | 'put'
  final double? bid;
  final double? ask;
  final double? mid;
  final double? last;
  final int? volume;
  final int? openInterest;
  final double? iv;
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;

  /// (ask - bid) / mid * 100. >10% = wide spread, untradeable in practice.
  final double? spreadPct;
  /// Days to expiration at the moment the snapshot was taken.
  final int? dte;
  /// Volume / open interest. >2.0 typically flags unusual activity.
  final double? volOiRatio;
  /// Premium as % of underlying — quick "is this an expensive contract" check.
  final double? premiumPct;

  /// IV rank: where current IV sits in the trailing 52-week range, 0-100.
  /// Rank ≥80 = premium expensive (favor credit strategies / spreads).
  /// Rank ≤20 = premium cheap (favor outright debit longs).
  final double? ivRank;
  /// IV percentile: % of past-year days where IV was BELOW today's level.
  final double? ivPercentile;
  /// True when this contract expires today. Different greeks behavior,
  /// different risk profile — UI shows a special 0DTE warning chip.
  final bool? isZeroDte;
  /// True when this ticker's next earnings falls BEFORE this contract's
  /// expiration. Buying through earnings = IV crush risk.
  final bool? earningsBeforeExpiry;

  bool get isCall => type == 'call';

  /// True when this contract was populated with real Polygon Options data
  /// (greeks present). UI uses this to decide whether to render the rich
  /// greeks/IV display or just the strike + expiration.
  bool get hasLiveData => delta != null && iv != null && mid != null;

  /// True when the spread is tight enough to actually trade. Use to flag
  /// contracts where the bid/ask gap means slippage > expected R.
  bool get isTradeable => spreadPct == null || spreadPct! <= 10;

  factory OptionContract.fromMap(Map<String, dynamic> m) {
    return OptionContract(
      symbol: (m['symbol'] ?? '') as String,
      underlying: (m['underlying'] ?? '') as String,
      strike: (m['strike'] as num?)?.toDouble() ?? 0,
      expiration: (m['expiration'] ?? '') as String,
      type: ((m['type'] ?? 'call') as String).toLowerCase(),
      bid: (m['bid'] as num?)?.toDouble(),
      ask: (m['ask'] as num?)?.toDouble(),
      mid: (m['mid'] as num?)?.toDouble(),
      last: (m['last'] as num?)?.toDouble(),
      volume: (m['volume'] as num?)?.toInt(),
      openInterest: (m['openInterest'] as num?)?.toInt(),
      iv: (m['iv'] as num?)?.toDouble(),
      delta: (m['delta'] as num?)?.toDouble(),
      gamma: (m['gamma'] as num?)?.toDouble(),
      theta: (m['theta'] as num?)?.toDouble(),
      vega: (m['vega'] as num?)?.toDouble(),
      spreadPct: (m['spreadPct'] as num?)?.toDouble(),
      dte: (m['dte'] as num?)?.toInt(),
      volOiRatio: (m['volOiRatio'] as num?)?.toDouble(),
      premiumPct: (m['premiumPct'] as num?)?.toDouble(),
      ivRank: (m['ivRank'] as num?)?.toDouble(),
      ivPercentile: (m['ivPercentile'] as num?)?.toDouble(),
      isZeroDte: m['isZeroDte'] as bool?,
      earningsBeforeExpiry: m['earningsBeforeExpiry'] as bool?,
    );
  }

  @override
  List<Object?> get props => [
        symbol,
        underlying,
        strike,
        expiration,
        type,
        bid,
        ask,
        mid,
        last,
        volume,
        openInterest,
        iv,
        delta,
        gamma,
        theta,
        vega,
        spreadPct,
        dte,
        volOiRatio,
        premiumPct,
        ivRank,
        ivPercentile,
        isZeroDte,
        earningsBeforeExpiry,
      ];
}
