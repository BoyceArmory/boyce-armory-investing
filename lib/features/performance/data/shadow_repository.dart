import '../../../core/services/api_client.dart';
import 'shadow_models.dart';

/// Talks to the backend shadow-performance endpoints. These are public
/// to all signed-in users (the auth middleware on /api/performance only
/// requires a logged-in user, not admin).
class ShadowRepository {
  ShadowRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<ShadowStats> fetchStats({int windowDays = 30}) async {
    final dynamic raw =
        await _api.getJson('/api/performance/shadow?days=$windowDays');
    if (raw is! Map<String, dynamic>) return ShadowStats.empty;
    return ShadowStats.fromJson(raw);
  }

  Future<List<ShadowTradeRecord>> fetchRecent({int limit = 50}) async {
    final dynamic raw =
        await _api.getJson('/api/performance/shadow/recent?limit=$limit');
    if (raw is! Map<String, dynamic>) return <ShadowTradeRecord>[];
    final List<dynamic> rawTrades = (raw['trades'] as List<dynamic>?) ?? <dynamic>[];
    return rawTrades
        .whereType<Map<String, dynamic>>()
        .map(ShadowTradeRecord.fromJson)
        .toList(growable: false);
  }

  Future<List<ShadowTradeRecord>> fetchOpen() async {
    final dynamic raw = await _api.getJson('/api/performance/shadow/open');
    if (raw is! Map<String, dynamic>) return <ShadowTradeRecord>[];
    final List<dynamic> rawTrades = (raw['trades'] as List<dynamic>?) ?? <dynamic>[];
    return rawTrades
        .whereType<Map<String, dynamic>>()
        .map(ShadowTradeRecord.fromJson)
        .toList(growable: false);
  }
}
