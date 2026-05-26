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
  /// Powers the "Recent Trades" list on the performance screen.
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
}
