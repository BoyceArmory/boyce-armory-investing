import 'package:equatable/equatable.dart';

class HomeOverview extends Equatable {
  const HomeOverview({
    required this.regime,
    required this.indices,
    required this.sectors,
    this.vix,
    this.news = const <NewsItem>[],
    this.events = const <EconEvent>[],
    this.performance,
    required this.asOf,
  });

  final MarketRegime regime;
  final List<MiniQuote> indices;
  final List<MiniQuote> sectors;
  final MiniQuote? vix;
  final List<NewsItem> news;
  final List<EconEvent> events;
  final DeskPerformance? performance;
  final DateTime asOf;

  factory HomeOverview.fromJson(Map<String, dynamic> j) {
    final regime = j['regime'] is Map<String, dynamic>
        ? MarketRegime.fromJson(j['regime'] as Map<String, dynamic>)
        : const MarketRegime.empty();
    final indices = (j['indices'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(MiniQuote.fromJson)
            .toList(growable: false) ??
        const <MiniQuote>[];
    final sectors = (j['sectors'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(MiniQuote.fromJson)
            .toList(growable: false) ??
        const <MiniQuote>[];
    final vix = j['vix'] is Map<String, dynamic>
        ? MiniQuote.fromJson(j['vix'] as Map<String, dynamic>)
        : null;
    final news = (j['news'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(NewsItem.fromJson)
            .toList(growable: false) ??
        const <NewsItem>[];
    final events = (j['events'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(EconEvent.fromJson)
            .toList(growable: false) ??
        const <EconEvent>[];
    final performance = j['performance'] is Map<String, dynamic>
        ? DeskPerformance.fromJson(j['performance'] as Map<String, dynamic>)
        : null;
    final asOf = DateTime.tryParse((j['asOf'] ?? '').toString()) ?? DateTime.now();
    return HomeOverview(
      regime: regime, indices: indices, sectors: sectors, vix: vix,
      news: news, events: events, performance: performance, asOf: asOf,
    );
  }

  @override
  List<Object?> get props => [regime, indices, sectors, vix, news, events, performance, asOf];
}

class NewsItem extends Equatable {
  const NewsItem({required this.headline, required this.url, this.source, this.time});
  final String headline;
  final String url;
  final String? source;
  final DateTime? time;

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        headline: (j['headline'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
        source: j['source'] as String?,
        time: j['time'] != null ? DateTime.tryParse(j['time'].toString()) : null,
      );

  @override
  List<Object?> get props => [headline, url, source, time];
}

class EconEvent extends Equatable {
  const EconEvent({required this.event, this.country, this.impact, this.time, this.actual, this.forecast, this.prev});
  final String event;
  final String? country;
  final String? impact;
  final String? time; // raw ISO
  final num? actual;
  final num? forecast;
  final num? prev;

  factory EconEvent.fromJson(Map<String, dynamic> j) => EconEvent(
        event: (j['event'] ?? '').toString(),
        country: j['country'] as String?,
        impact: j['impact'] as String?,
        time: j['time'] as String?,
        actual: j['actual'] as num?,
        forecast: j['forecast'] as num?,
        prev: j['prev'] as num?,
      );

  @override
  List<Object?> get props => [event, country, impact, time, actual, forecast, prev];
}

class DeskPerformance extends Equatable {
  const DeskPerformance({
    required this.totalTrades,
    required this.winRate,
    this.winningTrades = 0,
    this.losingTrades = 0,
    this.avgGainPct = 0,
    this.avgLossPct = 0,
    this.bestTradePct = 0,
    this.worstTradePct = 0,
  });
  final int totalTrades;
  final double winRate;
  final int winningTrades;
  final int losingTrades;
  final double avgGainPct;
  final double avgLossPct;
  final double bestTradePct;
  final double worstTradePct;

  factory DeskPerformance.fromJson(Map<String, dynamic> j) => DeskPerformance(
        totalTrades: (j['totalTrades'] as num?)?.toInt() ?? 0,
        winRate: (j['winRate'] as num?)?.toDouble() ?? 0,
        winningTrades: (j['winningTrades'] as num?)?.toInt() ?? 0,
        losingTrades: (j['losingTrades'] as num?)?.toInt() ?? 0,
        avgGainPct: (j['avgGainPct'] as num?)?.toDouble() ?? 0,
        avgLossPct: (j['avgLossPct'] as num?)?.toDouble() ?? 0,
        bestTradePct: (j['bestTradePct'] as num?)?.toDouble() ?? 0,
        worstTradePct: (j['worstTradePct'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [totalTrades, winRate, winningTrades, losingTrades,
        avgGainPct, avgLossPct, bestTradePct, worstTradePct];
}

class MarketRegime extends Equatable {
  const MarketRegime({
    required this.label,
    required this.trend,
    required this.risk,
    required this.color,
  });
  const MarketRegime.empty() : label = '—', trend = 'FLAT', risk = 'STEADY', color = 'neutral';

  final String label;
  final String trend; // BULLISH / FLAT / BEARISH
  final String risk;  // RISK ON / STEADY / CAUTION / RISK OFF
  final String color; // green / amber / red / neutral

  factory MarketRegime.fromJson(Map<String, dynamic> j) => MarketRegime(
        label: (j['label'] ?? '').toString(),
        trend: (j['trend'] ?? 'FLAT').toString(),
        risk: (j['risk'] ?? 'STEADY').toString(),
        color: (j['color'] ?? 'neutral').toString(),
      );

  @override
  List<Object?> get props => [label, trend, risk, color];
}

class MiniQuote extends Equatable {
  const MiniQuote({
    required this.symbol,
    required this.price,
    required this.changePct,
    this.name,
  });
  final String symbol;
  final double price;
  final double changePct;
  final String? name;

  factory MiniQuote.fromJson(Map<String, dynamic> j) => MiniQuote(
        symbol: (j['symbol'] ?? '').toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        changePct: (j['changePct'] as num?)?.toDouble() ?? 0,
        name: j['name'] as String?,
      );

  @override
  List<Object?> get props => [symbol, price, changePct, name];
}
