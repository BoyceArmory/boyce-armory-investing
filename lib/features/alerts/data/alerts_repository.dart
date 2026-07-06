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
        .map(_hardenDayCards)
        .map(_sortByConfidence);
  }

  /// Drop day-mode hot-trade cards that are clearly stale. Relaxed
  /// June 2026: only require currentPrice if the alert is also >1 hour
  /// old. Fresh alerts pass through even if the snapshot enrichment
  /// hasn't landed yet — the card renders with "—" for the price chip
  /// rather than getting hidden entirely.
  ///
  /// Also dedups by (mode, symbol) — defense-in-depth against legacy
  /// docs from an earlier keying scheme that still live in trade_alerts.
  /// The backend writes one doc per ticker per mode per day, so under
  /// normal operation this is a no-op. When a stale-schema duplicate is
  /// present, we keep the higher-scoring / snapshot-populated / newer
  /// card and drop the ghost.
  List<TradeAlert> _hardenDayCards(List<TradeAlert> alerts) {
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final List<TradeAlert> filtered = alerts.where((TradeAlert a) {
      if (a.mode == ScannerMode.day) {
        if (a.createdAt.isBefore(todayStart)) return false;
        final Duration age = now.difference(a.createdAt);
        if (age.inMinutes > 60 && a.currentPrice == null) return false;
      }
      return true;
    }).toList(growable: false);

    // Dedup by (mode, symbol). See scanner_repository for rationale.
    final Map<String, TradeAlert> byKey = <String, TradeAlert>{};
    for (final TradeAlert a in filtered) {
      final String modeWire = a.mode?.wire ?? 'unknown';
      final String key = '$modeWire:${a.symbol.toUpperCase()}';
      final TradeAlert? cur = byKey[key];
      if (cur == null) {
        byKey[key] = a;
        continue;
      }
      if (a.confidence > cur.confidence) {
        byKey[key] = a;
        continue;
      }
      if (a.confidence < cur.confidence) continue;
      final bool aHasSnap = a.currentPrice != null;
      final bool curHasSnap = cur.currentPrice != null;
      if (aHasSnap && !curHasSnap) {
        byKey[key] = a;
        continue;
      }
      if (!aHasSnap && curHasSnap) continue;
      if (a.createdAt.isAfter(cur.createdAt)) byKey[key] = a;
    }
    return byKey.values.toList(growable: false);
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

  /// Premarket watchlist — cards published by the backend premarket-scan job
  /// at 9:25 AM ET. Filtered by `kind == "premarket_watchlist"` so they don't
  /// clutter the Hot Trades feed but are easy to surface on the dedicated
  /// Premarket screen. Sorted by score (high → low) like the other lists.
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
