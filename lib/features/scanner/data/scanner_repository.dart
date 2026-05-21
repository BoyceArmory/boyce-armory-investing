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
  Stream<List<ScannerAlert>> streamPublicAlerts({
    int limit = 50,
    ScannerMode? mode,
  }) {
    Query<Map<String, dynamic>> q = _fs.scannerAlerts;
    if (mode != null) {
      q = q.where('mode', isEqualTo: mode.wire);
    }
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot);
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
