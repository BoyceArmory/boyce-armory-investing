import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_state_provider.dart';

/// Persistent per-user dismissed-tips map. Lives on
/// `users/{uid}.dismissedTips` as `{ tipId: true }`. The whatsNew banner,
/// future feature tours, and any other "show this once" UI flows read +
/// write through this service.
///
/// Stored in Firestore (not local prefs) so dismissing on phone also
/// hides the tip on iPad. Schema is open-ended — new tip ids can be
/// added without a migration.
class TipsService {
  TipsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  /// Streams the current dismissed-tips set. Empty set when no user or
  /// no field yet — both are treated as "show all tips".
  Stream<Set<String>> streamDismissed(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final raw = (data['dismissedTips'] as Map?) ?? const {};
      final out = <String>{};
      raw.forEach((k, v) {
        final key = k?.toString();
        if (key != null && v == true) out.add(key);
      });
      return out;
    });
  }

  /// Mark a tip as dismissed forever for this user. Merge-write so other
  /// tip flags on the same field are preserved.
  Future<void> dismiss(String uid, String tipId) async {
    await _userRef(uid).set({
      'dismissedTips': {tipId: true},
    }, SetOptions(merge: true));
  }
}

final Provider<TipsService> tipsServiceProvider =
    Provider<TipsService>((Ref ref) => TipsService());

/// Streams the dismissed-tip set for the current user, or an empty set
/// when signed out. Use [isTipDismissedProvider] for individual lookups
/// so widgets don't rebuild when an unrelated tip flips.
final StreamProvider<Set<String>> dismissedTipsProvider =
    StreamProvider<Set<String>>((Ref ref) {
  final User? user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream<Set<String>>.value(const <String>{});
  return ref.watch(tipsServiceProvider).streamDismissed(user.uid);
});

/// True when [tipId] has been dismissed by the current user.
final ProviderFamily<bool, String> isTipDismissedProvider =
    Provider.family<bool, String>((Ref ref, String tipId) {
  return ref.watch(dismissedTipsProvider).maybeWhen(
        data: (set) => set.contains(tipId),
        orElse: () => true, // hide while loading — avoids flash on cold start
      );
});
