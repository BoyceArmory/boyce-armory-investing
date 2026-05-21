import 'package:equatable/equatable.dart';

class MarketQuote extends Equatable {
  const MarketQuote({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePct,
    this.prevClose,
    this.high,
    this.low,
    this.asOf,
  });

  final String symbol;
  final double price;
  final double change;
  final double changePct;
  final double? prevClose;
  final double? high;
  final double? low;
  final DateTime? asOf;

  bool get isUp => change >= 0;

  factory MarketQuote.fromJson(Map<String, dynamic> m) {
    return MarketQuote(
      symbol: (m['symbol'] ?? '') as String,
      price: (m['price'] as num?)?.toDouble() ?? 0,
      change: (m['change'] as num?)?.toDouble() ?? 0,
      changePct: (m['changePct'] as num?)?.toDouble() ?? 0,
      prevClose: (m['prevClose'] as num?)?.toDouble(),
      high: (m['high'] as num?)?.toDouble(),
      low: (m['low'] as num?)?.toDouble(),
      asOf: m['asOf'] is String ? DateTime.tryParse(m['asOf'] as String) : null,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[symbol, price, change, changePct, prevClose, high, low, asOf];
}

class MarketContext extends Equatable {
  const MarketContext({
    this.spy,
    this.qqq,
    this.dia,
    this.vix,
    this.asOf,
  });

  final MarketQuote? spy;
  final MarketQuote? qqq;
  final MarketQuote? dia;
  final MarketQuote? vix;
  final DateTime? asOf;

  factory MarketContext.fromJson(Map<String, dynamic> m) {
    MarketQuote? parse(Object? raw) {
      if (raw is Map<String, dynamic>) return MarketQuote.fromJson(raw);
      return null;
    }
    return MarketContext(
      spy: parse(m['spy']),
      qqq: parse(m['qqq']),
      dia: parse(m['dia']),
      vix: parse(m['vix']),
      asOf: m['asOf'] is String ? DateTime.tryParse(m['asOf'] as String) : null,
    );
  }

  @override
  List<Object?> get props => <Object?>[spy, qqq, dia, vix, asOf];
}
