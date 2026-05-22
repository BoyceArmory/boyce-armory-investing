import '../../../core/services/api_client.dart';

class SupportRepository {
  SupportRepository({required ApiClient apiClient}) : _api = apiClient;
  final ApiClient _api;

  /// Submit a support / trouble ticket. Backend attaches the signed-in user's
  /// uid + email so the client can't spoof.
  Future<String> submitTicket({
    required String category, // bug | feature | billing | account | other
    required String subject,
    required String message,
    String? appVersion,
    String? platform,
    String? device,
  }) async {
    final j = await _api.postJson('/api/support/tickets', body: {
      'category': category,
      'subject': subject,
      'message': message,
      if (appVersion != null) 'appVersion': appVersion,
      if (platform != null) 'platform': platform,
      if (device != null) 'device': device,
    });
    return (j['id'] as String?) ?? '';
  }
}
