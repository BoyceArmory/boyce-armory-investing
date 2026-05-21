import 'package:equatable/equatable.dart';

/// Suggested option contract attached to a scanner alert.
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

  bool get isCall => type == 'call';

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
      ];
}
