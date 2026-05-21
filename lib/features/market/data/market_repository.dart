import '../../../core/models/market_context_model.dart';
import '../../../core/services/api_client.dart';

class MarketRepository {
  MarketRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<MarketContext> fetchContext() async {
    final Map<String, dynamic> json = await _api.getJson('/api/market/context');
    return MarketContext.fromJson(json);
  }
}
