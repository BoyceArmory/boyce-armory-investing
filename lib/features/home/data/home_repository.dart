import '../../../core/services/api_client.dart';
import 'home_overview_model.dart';

class HomeRepository {
  HomeRepository({required ApiClient apiClient}) : _api = apiClient;
  final ApiClient _api;

  Future<HomeOverview> fetchOverview() async {
    final j = await _api.getJson('/api/market/home-overview');
    return HomeOverview.fromJson(j);
  }
}
