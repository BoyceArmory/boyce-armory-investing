import '../../../core/services/api_client.dart';
import 'home_overview_model.dart';

class HomeRepository {
  HomeRepository({required ApiClient apiClient}) : _api = apiClient;
  final ApiClient _api;

  Future<HomeOverview> fetchOverview() async {
    final j = await _api.getJson('/api/market/home-overview');
    return HomeOverview.fromJson(j);
  }

  /// IV-rank summary for SPY/QQQ/IWM. Returns one IvRankItem per ticker,
  /// plus an `enabled` flag — when the options data service isn't
  /// configured on the backend the card renders an "enable options"
  /// empty state instead of broken rows.
  Future<IvRankSummary> fetchIvRankSummary() async {
    final j = await _api.getJson('/api/market/iv-rank');
    return IvRankSummary.fromJson(j);
  }
}

class IvRankSummary {
  const IvRankSummary({required this.enabled, required this.items});
  final bool enabled;
  final List<IvRankItem> items;

  factory IvRankSummary.fromJson(Map<String, dynamic> j) {
    final raw = (j['items'] as List?) ?? const [];
    return IvRankSummary(
      enabled: j['enabled'] == true,
      items: raw
          .whereType<Map<String, dynamic>>()
          .map(IvRankItem.fromJson)
          .toList(),
    );
  }
}

class IvRankItem {
  const IvRankItem({
    required this.ticker,
    required this.iv,
    required this.rank,
    required this.percentile,
  });
  final String ticker;
  final double? iv;
  final double? rank;
  final double? percentile;

  factory IvRankItem.fromJson(Map<String, dynamic> j) => IvRankItem(
        ticker: (j['ticker'] ?? '').toString(),
        iv: (j['iv'] as num?)?.toDouble(),
        rank: (j['rank'] as num?)?.toDouble(),
        percentile: (j['percentile'] as num?)?.toDouble(),
      );
}
