import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/scanner_alert_model.dart';
import '../../../core/services/firestore_service.dart';

/// Firestore data source for scanner alerts.
///
/// Two collections live here:
///   - `scanner_alerts`  : public-visible signals (default for customers)
///   - `scanner_results` : every signal, admin-only
class ScannerRepository {
  ScannerRepository({required FirestoreService firestoreService})
      : _fs = firestoreService;

  final FirestoreService _fs;

  /// Live stream of recent public scanner alerts. Optionally filter by mode.
  ///
  /// The visibility filter is defence-in-depth: the backend only writes
  /// public docs to `scanner_alerts`, but adding the filter here means the
  /// UI ignores anything that accidentally slips through.
  ///
  /// Decay filter: docs marked `still_valid: false` by the backend decay
  /// job are hidden in the client. The decay job re-checks each card every
  /// 5 minutes and invalidates ones whose price has run past entry/stop,
  /// extended too far, or where the snapshot at scan time turned out to be
  /// wrong (caught the META $725 vs $608 bug). Without this filter the UI
  /// keeps showing stale or bad-data cards even after the backend knows
  /// they're no longer actionable.
  Stream<List<ScannerAlert>> streamPublicAlerts({
    int limit = 50,
    ScannerMode? mode,
  }) {
    Query<Map<String, dynamic>> q = _fs.scannerAlerts
        .where('visibility', isEqualTo: AlertVisibility.public.wire);
    if (mode != null) {
      q = q.where('mode', isEqualTo: mode.wire);
    }
    // We still order by createdAt at the Firestore level so the query stays
    // efficient and the `limit` filters by most-recent. Then we re-sort the
    // resulting page client-side by score (high → low) and fall back to
    // createdAt (newest → oldest) when scores tie. This gives users the
    // strongest setups at the top while keeping the live stream lightweight.
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot)
        .map((List<ScannerAlert> alerts) {
      final List<ScannerAlert> visible = alerts
          .where((ScannerAlert a) => a.stillValid != false)
          .toList();
      visible.sort((ScannerAlert a, ScannerAlert b) {
        final int scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return visible;
    });
  }

  /// Live stream of every scanner result (admin only). Optionally filter by mode.
  Stream<List<ScannerAlert>> streamAllResults({
    int limit = 100,
    ScannerMode? mode,
  }) {
    Query<Map<String, dynamic>> q = _fs.scannerResults;
    if (mode != null) {
      q = q.where('mode', isEqualTo: mode.wire);
    }
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot);
  }

  /// One-shot fetch by id, used by detail screens.
  Future<ScannerAlert?> fetchById(String id) async {
    final DocumentSnapshot<Map<String, dynamic>> pub =
        await _fs.scannerAlerts.doc(id).get();
    if (pub.exists && pub.data() != null) {
      return ScannerAlert.fromMap(pub.id, pub.data()!);
    }
    final DocumentSnapshot<Map<String, dynamic>> adm =
        await _fs.scannerResults.doc(id).get();
    if (adm.exists && adm.data() != null) {
      return ScannerAlert.fromMap(adm.id, adm.data()!);
    }
    return null;
  }

  Stream<ScannerAlert?> streamById(String id) {
    return _fs.scannerAlerts.doc(id).snapshots().map((s) {
      if (!s.exists || s.data() == null) return null;
      return ScannerAlert.fromMap(s.id, s.data()!);
    });
  }

  List<ScannerAlert> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> q) {
    return q.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            ScannerAlert.fromMap(d.id, d.data()))
        .toList(growable: false);
  }
}
