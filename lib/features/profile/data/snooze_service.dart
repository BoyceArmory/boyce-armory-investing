import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_state_provider.dart';

/// Streams the current user's `notificationPrefs.snoozeUntil` field as a
/// DateTime?. Emits null when:
///   - no user is signed in
///   - the field is absent or empty
///   - the parsed timestamp is in the past (snooze has expired)
///
/// Used to surface a persistent "You're snoozed" indicator outside of
/// the Settings screen so users don't forget they silenced themselves.
/// Polls the user doc via Firestore snapshots, so any device that updates
/// snooze sees the change near-instantly on every other device.
final StreamProvider<DateTime?> activeSnoozeProvider =
    StreamProvider<DateTime?>((Ref ref) {
  final User? user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream<DateTime?>.value(null);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    final prefs = (data['notificationPrefs'] as Map?) ?? const {};
    final raw = (prefs['snoozeUntil'] as String?) ?? '';
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.isBefore(DateTime.now())) return null;
    return parsed;
  });
});

/// Streams the master notification toggle from the user doc. Defaults to
/// true when the field is absent (factory default) or the user isn't
/// signed in. Cheaper than re-fetching the full prefs via the API every
/// time a screen wants to render "Notifications: ON".
final StreamProvider<bool> masterNotifProvider =
    StreamProvider<bool>((Ref ref) {
  final User? user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream<bool>.value(true);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    final prefs = (data['notificationPrefs'] as Map?) ?? const {};
    return prefs['master'] != false;
  });
});
