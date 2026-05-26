import '../../../core/services/api_client.dart';
import 'system_status_model.dart';

/// REST data source for the admin tab. All endpoints under /api/admin/* are
/// gated by requireAdmin on the backend (verifies Firebase ID token + role).
class AdminRepository {
  AdminRepository({required ApiClient apiClient}) : _api = apiClient;
  final ApiClient _api;

  // ---- System status / kill switches ----------------------------------

  Future<SystemStatus> fetchSystemStatus() async {
    final j = await _api.getJson('/api/admin/system/status');
    return SystemStatus.fromJson(j);
  }

  Future<Map<String, dynamic>> fetchFlags() async {
    return _api.getJson('/api/admin/system/flags');
  }

  /// Set the scheduler-enabled flag. Pass null to clear the override and
  /// revert to the env default.
  Future<void> setSchedulerEnabled(bool? value) async {
    await _api.postJson('/api/admin/system/flags', body: {'schedulerEnabled': value});
  }

  /// Set the scanner-push flag. Pass null to clear the override.
  Future<void> setPushScannerPromotes(bool? value) async {
    await _api.postJson('/api/admin/system/flags', body: {'pushScannerPromotes': value});
  }

  // ---- Chat broadcast (ADMIN BUYS) ------------------------------------

  /// Fire an FCM push to every active device for an admin chat post.
  /// Called immediately after a successful Firestore write in an admin-only
  /// + broadcastPush room (e.g. "admin_buys"). Backend fan-out keeps the
  /// push under a single privileged endpoint so non-admins can't spam.
  ///
  /// Safe to ignore failure — the chat message is already saved in Firestore;
  /// the broadcast is best-effort. Surface the error in admin UI but don't
  /// block the user.
  Future<void> broadcastChatMessage({
    required String roomId,
    required String roomTitle,
    required String messageId,
    required String text,
    required String messageType, // "text" | "image"
    String? imageUrl,
  }) async {
    await _api.postJson('/api/admin/chat-broadcast', body: {
      'roomId': roomId,
      'roomTitle': roomTitle,
      'messageId': messageId,
      'text': text,
      'messageType': messageType,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    });
  }

  // ---- Scanner ops ----------------------------------------------------

  Future<void> triggerScan({
    required String mode,
    bool force = false,
    List<String>? tickers,
  }) async {
    await _api.postJson('/api/admin/scanner/run', body: {
      'mode': mode,
      'force': force,
      if (tickers != null && tickers.isNotEmpty) 'tickers': tickers,
    });
  }

  Future<List<Map<String, dynamic>>> listScannerRuns({String? mode, int limit = 50}) async {
    final q = <String>['limit=$limit'];
    if (mode != null) q.add('mode=$mode');
    final j = await _api.getJson('/api/admin/scanner/runs?${q.join("&")}');
    return ((j['runs'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  // ---- Alerts ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listScannerAlerts({bool includeAdmin = false, int limit = 50}) async {
    final j = await _api.getJson(
      '/api/admin/alerts/scanner?limit=$limit&includeAdmin=$includeAdmin',
    );
    return ((j['alerts'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> setScannerVisibility(String id, String visibility) async {
    await _api.postJson('/api/admin/alerts/scanner/$id/visibility',
        body: {'visibility': visibility});
  }

  Future<String> promoteScannerToHot(String id) async {
    final j = await _api.postJson('/api/admin/alerts/scanner/$id/promote');
    return (j['tradeAlertId'] as String?) ?? '';
  }

  Future<List<Map<String, dynamic>>> listTradeAlerts({bool onlyHot = false, int limit = 50}) async {
    final j = await _api.getJson('/api/admin/alerts/trade?limit=$limit&onlyHot=$onlyHot');
    return ((j['alerts'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<String> createTradeAlert(Map<String, dynamic> body) async {
    final j = await _api.postJson('/api/admin/alerts/trade', body: body);
    return (j['id'] as String?) ?? '';
  }

  Future<void> patchTradeAlert(String id, {bool? isHot, String? visibility}) async {
    final body = <String, dynamic>{};
    if (isHot != null) body['isHot'] = isHot;
    if (visibility != null) body['visibility'] = visibility;
    await _api.postJson('/api/admin/alerts/trade/$id', body: body);
  }

  // ---- Users -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listUsers({int limit = 100}) async {
    final j = await _api.getJson('/api/admin/users?limit=$limit');
    return ((j['users'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> setRole(String uid, String role) async {
    await _api.postJson('/api/admin/users/role', body: {'uid': uid, 'role': role});
  }

  Future<void> setTier(String uid, String tier) async {
    await _api.postJson('/api/admin/users/$uid/tier', body: {'tier': tier});
  }

  Future<void> setDisabled(String uid, bool disabled) async {
    await _api.postJson('/api/admin/users/$uid/disabled', body: {'disabled': disabled});
  }

  // ---- Trades ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listActiveTrades({int limit = 50}) async {
    final j = await _api.getJson('/api/admin/trades/active?limit=$limit');
    return ((j['trades'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listClosedTrades({int limit = 50}) async {
    final j = await _api.getJson('/api/admin/trades/closed?limit=$limit');
    return ((j['trades'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  Future<void> closeTrade(String id, double exit, {String? notes}) async {
    await _api.postJson('/api/admin/trades/$id/close', body: {
      'exit': exit,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  // ---- Audit -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listAuditLogs({int limit = 100}) async {
    final j = await _api.getJson('/api/admin/audit?limit=$limit');
    return ((j['logs'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  // ---- Recap ----------------------------------------------------------

  Future<void> triggerRecap() async {
    await _api.postJson('/api/admin/recap/run');
  }
}
