import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/api_client.dart';
import 'performance_models.dart';

/// Data source for the customer-facing performance / track-record page.
///
/// Aggregated stats live in `performance_stats` (computed server-side by
/// the recap cron + admin "close trade" action). We fetch them via the
/// public `/api/performance/` endpoint.
///
/// Recent closed trades are read directly from Firestore — the `closed_trades`
/// collection is readable by any signed-in user (Firestore rules), so we can
/// stream them without going through the backend.
class PerformanceRepository {
  PerformanceRepository({
    required ApiClient apiClient,
    FirebaseFirestore? firestore,
  })  : _api = apiClient,
        _db = firestore ?? FirebaseFirestore.instance;

  final ApiClient _api;
  final FirebaseFirestore _db;

  /// Fetch the all-time global stats. Returns [PerformanceStats.empty] if
  /// the backend has no document yet (fresh launch, before any trade closes).
  Future<PerformanceStats> fetchGlobalStats() async {
    final dynamic raw = await _api.getJson('/api/performance/');
    if (raw == null) return PerformanceStats.empty;
    if (raw is! Map<String, dynamic>) return PerformanceStats.empty;
    return PerformanceStats.fromJson(raw);
  }

  /// Fetch stats for a specific month (YYYY-MM). Returns null if no doc.
  Future<PerformanceStats?> fetchMonthStats(String monthKey) async {
    final dynamic raw = await _api.getJson('/api/performance/month/$monthKey');
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) return null;
    return PerformanceStats.fromJson(raw);
  }

  /// Live stream of the [limit] most-recent closed trades, newest first.
  /// Powers the "Recent Trades" list on the performance screen. Returns
  /// every doc regardless of `source` — callers needing only real or only
  /// shadow trades should use the dedicated streams below.
  Stream<List<ClosedTrade>> streamRecentClosedTrades({int limit = 25}) {
    return _db
        .collection('closed_trades')
        .orderBy('closedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ClosedTrade.fromSnapshot(d),
              )
              .toList(growable: false),
        );
  }

  /// User-taken trades only (real positions closed by admin or bulk-import).
  /// We over-fetch and then filter in-memory because Firestore's `!=` query
  /// would exclude legacy docs that lack the `source` field altogether
  /// (those are real trades — pre-shadow-feature uploads).
  ///
  /// Reason for the dedicated stream: with ~10-15 shadow trades closing per
  /// day, the unified stream's recent slice fills with shadows and pushes
  /// older real trades out of view, which made the My Trades tab look
  /// empty even when Webull history had been imported.
  Stream<List<ClosedTrade>> streamUserClosedTrades({int limit = 100}) {
    return _db
        .collection('closed_trades')
        .orderBy('closedAt', descending: true)
        .limit(limit * 3) // over-fetch — shadow trades dominate recent slice
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      final List<ClosedTrade> all = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ClosedTrade.fromSnapshot(d))
          .toList();
      final List<ClosedTrade> userOnly =
          all.where((ClosedTrade t) => t.isUserTrade).toList(growable: false);
      // Apply the user-facing limit after filtering so the tab isn't
      // accidentally short when shadow trades dominate the over-fetch.
      return userOnly.length > limit ? userOnly.sublist(0, limit) : userOnly;
    });
  }

  /// Scanner-tracked simulated outcomes only. Queries on the indexed
  /// `source == "shadow"` constraint so we don't need to over-fetch.
  Stream<List<ClosedTrade>> streamShadowClosedTrades({int limit = 100}) {
    return _db
        .collection('closed_trades')
        .where('source', isEqualTo: 'shadow')
        .orderBy('closedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    ClosedTrade.fromSnapshot(d),
              )
              .toList(growable: false),
        );
  }
}
