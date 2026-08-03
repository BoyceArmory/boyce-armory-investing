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

  // ---- Push diagnostics ------------------------------------------------
  // Used by Settings → Admin → "Send test push" to verify the entire push
  // pipeline (FCM token → APNs/FCM dispatch → device display) is working.

  /// Fire a test broadcast push to every active device token. Returns the
  /// number of devices it reached, failure count, and a warning if no tokens
  /// are registered (which is the most common cause of "I'm not getting
  /// pushes" — the user hasn't granted permission yet).
  Future<Map<String, dynamic>> sendTestPush() async {
    return _api.postJson('/api/admin/push/test');
  }

  /// List registered device tokens (no token strings — those grant push to
  /// a device, never expose). Useful for diagnosing "I'm not getting
  /// pushes" — if your uid doesn't appear in the list, your token never
  /// registered with the backend.
  Future<Map<String, dynamic>> listDeviceTokens() async {
    return _api.getJson('/api/admin/push/devices');
  }

  // ---- Job triggers (Jobs tab) ----------------------------------------

  /// Wipe stale scanner_alerts + trade_alerts (preserves demos). Same
  /// logic as the daily 9:31 AM reset, on demand.
  Future<Map<String, dynamic>> wipeStale() async {
    return _api.postJson('/api/admin/alerts/wipe-stale');
  }

  /// Insert 3 demo trade_alerts so reviewers / new users always see content.
  Future<Map<String, dynamic>> seedDemoAlerts() async {
    return _api.postJson('/api/admin/alerts/seed-demo', body: {});
  }

  /// Remove the 3 demo seeds. Pass when scanner has enough real signals
  /// that the demos are no longer needed.
  Future<Map<String, dynamic>> clearDemoAlerts() async {
    return _api.postJson('/api/admin/alerts/seed-demo', body: {'clear': true});
  }

  /// Trigger the daily recap aggregation manually. Daily cron runs this at
  /// 5 PM ET; this button is for "I just bulk-imported trades and want the
  /// performance widget to reflect them right now."
  Future<void> triggerDailyRecap() async {
    await _api.postJson('/api/admin/recap/run', body: {});
  }

  // ---- Bulk trade import ---------------------------------------------

  /// Upload a batch of closed trades. Expected body shape:
  ///   { "trades": [ { symbol, direction, entry, exit, qty?, closedAt,
  ///                   idempotencyKey?, contract? }, ... ] }
  /// Returns { received, imported, skipped, errors }. Idempotency keys
  /// keep repeat-fires safe.
  Future<Map<String, dynamic>> bulkImportTrades(
      List<Map<String, dynamic>> trades) async {
    return _api.postJson('/api/admin/trades/bulk-import',
        body: {'trades': trades});
  }

  // ---- Detector control panel ----------------------------------------

  /// Replace the runtime disabled-detector list. Pass an empty list to
  /// re-enable everything. Keys are `${mode}_${kind}` (e.g. "swing_breakout").
  Future<List<String>> setDisabledDetectors(List<String> keys) async {
    final r = await _api.postJson('/api/admin/detectors', body: {
      'disabledDetectors': keys,
    });
    final out = (r['disabledDetectors'] as List?) ?? const <dynamic>[];
    return out.map((e) => e.toString()).toList(growable: false);
  }

  /// Manually trigger the weekly auto-demote sweep. Same logic as the cron:
  /// any (mode,kind) with expectancyPct <= -0.1 AND totalTrades >= 100 gets
  /// merged into the disabled list. Returns { scanned, flagged, newlyDisabled,
  /// alreadyDisabled }.
  Future<Map<String, dynamic>> runAutoDemote() async {
    return _api.postJson('/api/admin/detectors/auto-demote', body: {});
  }

  // ---- Backtest viewer ------------------------------------------------
  // Read setup_stats rows (per (mode, kind) with regime breakdown). Used
  // by the Backtest screen to show measured per-detector edge.

  /// Live cooldown table snapshot — every (symbol, kind, mode) currently
  /// silenced by the scanner. Returns each row as a Map keyed by:
  /// mode, symbol, kind, lastScore, minutesAgo, minutesUntilExpiry,
  /// fireCount, failedAt, lastPublishedAt. Used by the admin Cooldowns
  /// tab so the "why no AAPL alert today?" question has an answer.
  Future<List<Map<String, dynamic>>> fetchCooldowns() async {
    final j = await _api.getJson('/api/admin/cooldowns');
    final rows = (j['cooldowns'] as List?) ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchBacktestStats() async {
    final j = await _api.getJson('/api/admin/backtest/stats');
    final rows = (j['rows'] as List?) ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Trigger a fresh backtest run on the backend. Returns the summary
  /// counts (tickers scanned, groups, total trades) so the UI can show a
  /// "computed N trades across M kinds" confirmation.
  Future<Map<String, dynamic>> runBacktest() async {
    return _api.postJson('/api/admin/backtest/run', body: {});
  }

  /// Lightweight backtest health summary for the Status tab. Returns
  /// totalDetectors / profitable / losing / topEdgePct / lastRunAt /
  /// autoDemoteCandidates so the at-a-glance card doesn't need to load the
  /// full setup_stats roster.
  Future<Map<String, dynamic>> fetchBacktestHealth() async {
    return _api.getJson('/api/admin/backtest/health');
  }

  /// @everyone broadcast — fires an arbitrary push to every active device.
  /// When `force` is true, bypasses user-side announcement mute (use only
  /// for genuine emergencies — app outage, market early close, etc).
  /// Returns delivery counts.
  Future<Map<String, dynamic>> announce({
    required String title,
    required String body,
    String? deepLink,
    bool force = false,
  }) async {
    return _api.postJson('/api/admin/push/announce', body: {
      'title': title,
      'body': body,
      if (deepLink != null) 'deepLink': deepLink,
      if (force) 'force': true,
    });
  }

  // ---- Per-user notification preferences -------------------------------
  // These hit /api/users/me/notifications which is mounted under requireAuth
  // (NOT requireAdmin) — every signed-in user can read + update their own
  // toggles. Lives on the admin repo because that's where the api client is
  // wired; a 2.1.1 refactor will lift these into a dedicated profile repo.

  Future<Map<String, dynamic>> fetchMyNotificationPrefs() async {
    return _api.getJson('/api/users/me/notifications');
  }

  Future<void> updateMyNotificationPrefs(Map<String, bool> prefs) async {
    await _api.patchJson('/api/users/me/notifications', body: prefs);
  }

  /// Update advanced (non-boolean) preferences in one call. Supports the
  /// scannerMinGrade enum string, the nested scannerModes object, and the
  /// nested quietHours object. Pass only the fields you want to change —
  /// the backend merges into existing prefs.
  Future<void> updateMyNotificationPrefsAdvanced(
      Map<String, dynamic> patch) async {
    await _api.patchJson('/api/users/me/notifications', body: patch);
  }

  /// Write/update the journal note on one of the user's own closed
  /// trades. Empty string clears the note. Returns the persisted value
  /// the server saw so the client can update local state without a
  /// re-fetch.
  Future<String> updateMyTradeNotes(String tradeId, String notes) async {
    final j = await _api.patchJson(
      '/api/users/me/trades/$tradeId/notes',
      body: <String, dynamic>{'notes': notes},
    );
    return (j['notes'] as String?) ?? notes;
  }

  /// Self-service push diagnostic. Returns:
  ///   - sent / failureCount / deviceCount: numbers from the FCM result
  ///   - suppressedBy: "master_off" | "scanner_off" | "snooze" | "quiet_hours" | null
  ///   - snoozeUntil: only present when suppressedBy=="snooze"
  ///   - warning: present when no tokens registered (device hasn't granted push)
  Future<Map<String, dynamic>> sendMyTestPush() async {
    return _api.postJson('/api/users/me/test-push');
  }

  /// One-shot reset of every push-related preference back to factory
  /// defaults. Hits the same PATCH endpoint as updateMy*; we just send
  /// every key with its default value in a single request. Chat mutes
  /// (which live under users/{uid}.chatMutes, not notificationPrefs)
  /// need a separate Firestore write — the Settings screen pairs this
  /// call with a ChatPrefsService clear so reset means "everything off."
  Future<void> resetMyNotificationPrefs() async {
    await _api.patchJson('/api/users/me/notifications', body: <String, dynamic>{
      'master': true,
      'scanner': true,
      'hot': true,
      'adminBuys': true,
      'premarket': true,
      'recap': true,
      'announcement': true,
      'scannerMinGrade': 'all',
      'scannerModes': {'day': true, 'swing': true, 'leaps': true},
      'quietHours': {'enabled': false, 'startHour': 22, 'endHour': 6},
      'snoozeUntil': '',
    });
  }

  /// In-app notification center feed. Returns the last 50 broadcast pushes
  /// (audience='all'). Each item carries the original deepLink so taps can
  /// reuse the existing FCM tap handler. Today every push is a broadcast;
  /// per-user targeting may filter further in the future.
  Future<List<Map<String, dynamic>>> fetchMyNotificationHistory() async {
    final j = await _api.getJson('/api/users/me/notification-history');
    final items = (j['items'] as List?) ?? const <dynamic>[];
    return items.whereType<Map<String, dynamic>>().toList(growable: false);
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

  // ---- Users -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listUsers({int limit = 100}) async {
    final j = await _api.getJson('/api/admin/users?limit=$limit');
    return ((j['users'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// Rich per-user detail — user doc + push tokens count + recent
  /// actions + watchlist preview. Backs the Users-tab tap-to-expand
  /// bottom sheet. Errors bubble so the sheet's error state can show.
  Future<Map<String, dynamic>> fetchUserDetail(String uid) async {
    final j = await _api.getJson('/api/admin/users/$uid/detail');
    return j;
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

  // ---- Admin events feed (in-app inbox for new signups, etc.) ----------
  //
  // Backed by the new-account-watcher cron + admin_events Firestore
  // collection. Each event has kind, loggedAt, read, and kind-specific
  // fields. Today the only kind is "new_account"; the schema is open so
  // future event types (support tickets, system alerts) drop in without
  // a migration.

  /// Fetch recent admin events newest first.
  ///   limit:      hard cap on result count (server caps at 500).
  ///   onlyUnread: when true, only returns events with read == false.
  Future<List<Map<String, dynamic>>> listAdminEvents({
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    final qs = StringBuffer('?limit=$limit');
    if (onlyUnread) qs.write('&unread=true');
    final j = await _api.getJson('/api/admin/events$qs');
    return ((j['events'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// Mark a single event as read.
  Future<void> markAdminEventRead(String id) async {
    await _api.patchJson('/api/admin/events/$id/read');
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
