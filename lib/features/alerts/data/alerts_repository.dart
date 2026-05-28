import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/trade_alert_model.dart';
import '../../../core/services/firestore_service.dart';

class AlertsRepository {
  AlertsRepository({required FirestoreService firestoreService})
      : _fs = firestoreService;

  final FirestoreService _fs;

  Stream<List<TradeAlert>> streamRecent({int limit = 50, bool onlyPublic = true}) {
    Query<Map<String, dynamic>> q = _fs.tradeAlerts
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (onlyPublic) {
      q = q.where('visibility', isEqualTo: AlertVisibility.public.wire);
    }
    return q.snapshots().map(_mapSnapshot).map(_sortByConfidence);
  }

  Stream<List<TradeAlert>> streamHot({int limit = 25}) {
    // CRITICAL: the visibility filter MUST be present in the query, not just
    // in the rules. Firestore evaluates security rules against the query
    // itself - it doesn't peek at the result data first. The rule on
    // `trade_alerts` requires non-admin reads to be constrained on
    // visibility == 'public'. Without this `.where()` line, every non-admin
    // user hits cloud_firestore/permission-denied on the Hot Trades page.
    // Admins bypass via isAdmin() in the rule, which is why this bug was
    // invisible to Jonathan and only surfaced once testers signed in.
    return _fs.tradeAlerts
        .where('isHot', isEqualTo: true)
        .where('visibility', isEqualTo: AlertVisibility.public.wire)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot)
        .map(_sortByConfidence);
  }

  /// Rank alerts strongest → weakest. We still page by recency at the
  /// Firestore layer (cheap query + a useful "freshness" floor), but users
  /// scrolling Hot Trades expect the highest-confidence setup at the top, not
  /// just the most recent. Ties fall back to `createdAt` newest-first.
  List<TradeAlert> _sortByConfidence(List<TradeAlert> alerts) {
    final List<TradeAlert> ranked = List<TradeAlert>.from(alerts);
    ranked.sort((TradeAlert a, TradeAlert b) {
      final int cmp = b.confidence.compareTo(a.confidence);
      if (cmp != 0) return cmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return ranked;
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
