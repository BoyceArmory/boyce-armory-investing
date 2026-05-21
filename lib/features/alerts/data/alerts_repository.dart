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
    return q.snapshots().map(_mapSnapshot);
  }

  Stream<List<TradeAlert>> streamHot({int limit = 25}) {
    return _fs.tradeAlerts
        .where('isHot', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot);
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
