import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/trade_alert_model.dart';
import '../../../core/services/firestore_service.dart';

class AlertsRepository {
  AlertsRepository({required FirestoreService firestoreService})
      : _fs = firestoreService;

  final FirestoreService _fs;

  /// Rank alerts strongest → weakest. We still page by recency at the
  /// Firestore layer (cheap query + a useful "freshness" floor), but users
  /// scrolling the Premarket Watchlist expect the highest-confidence setup
  /// at the top, not just the most recent. Ties fall back to `createdAt`
  /// newest-first.
  List<TradeAlert> _sortByConfidence(List<TradeAlert> alerts) {
    final List<TradeAlert> ranked = List<TradeAlert>.from(alerts);
    ranked.sort((TradeAlert a, TradeAlert b) {
      final int cmp = b.confidence.compareTo(a.confidence);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return ranked;
  }

  /// Premarket watchlist — cards published by the backend premarket-scan job
  /// at 9:25 AM ET. Filtered by `kind == "premarket_watchlist"` so they're
  /// easy to surface on the dedicated Premarket screen. Sorted by score
  /// (high → low) like the other lists.
  Stream<List<TradeAlert>> streamPremarket({int limit = 30}) {
    return _fs.tradeAlerts
        .where('kind', isEqualTo: 'premarket_watchlist')
        .where('visibility', isEqualTo: AlertVisibility.public.wire)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot)
        .map(_sortByConfidence);
  }

  Stream<TradeAlert?> streamById(String id) {
    return _fs.tradeAlerts.doc(id).snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return TradeAlert.fromMap(s.id, s.data()!);
    });
  }

  Future<TradeAlert?> fetchById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _fs.tradeAlerts.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return TradeAlert.fromMap(snap.id, snap.data()!);
  }

  List<TradeAlert> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> q) {
    return q.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            TradeAlert.fromMap(d.id, d.data()))
        .toList(growable: false);
  }
}
