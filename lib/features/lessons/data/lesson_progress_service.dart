import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_state_provider.dart';

/// Streams + writes the per-user lesson completion set. Lives at
/// `users/{uid}.completedLessons` as an array of lesson ids
/// (`["how-to-read-alerts", "using-snooze", ...]`).
///
/// Used by the Learn tab to render a checkmark next to read lessons and
/// to show a small progress bar across each section. The set is built
/// once per user-doc snapshot and cached by Riverpod, so per-lesson
/// lookups are O(1) and don't refetch.
class LessonProgressService {
  LessonProgressService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  Stream<Set<String>> streamCompleted(String uid) {
    return _userRef(uid).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      final raw = (data['completedLessons'] as List?) ?? const <dynamic>[];
      final out = <String>{};
      for (final e in raw) {
        if (e is String && e.isNotEmpty) out.add(e);
      }
      return out;
    });
  }

  /// Add [lessonId] to the user's completed set. arrayUnion-style write
  /// so concurrent reads don't clobber each other. Idempotent — calling
  /// twice has no effect on storage.
  Future<void> markCompleted(String uid, String lessonId) async {
    await _userRef(uid).set({
      'completedLessons': FieldValue.arrayUnion([lessonId]),
    }, SetOptions(merge: true));
  }

  /// Remove [lessonId] from the user's completed set. Useful if a user
  /// wants to mark a lesson "unread" again for review.
  Future<void> markIncomplete(String uid, String lessonId) async {
    await _userRef(uid).set({
      'completedLessons': FieldValue.arrayRemove([lessonId]),
    }, SetOptions(merge: true));
  }
}

final Provider<LessonProgressService> lessonProgressServiceProvider =
    Provider<LessonProgressService>((Ref ref) => LessonProgressService());

/// Streams the current user's completed-lessons set. Empty set when no
/// user is signed in.
final StreamProvider<Set<String>> completedLessonsProvider =
    StreamProvider<Set<String>>((Ref ref) {
  final User? user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream<Set<String>>.value(const <String>{});
  return ref
      .watch(lessonProgressServiceProvider)
      .streamCompleted(user.uid);
});

/// O(1) per-lesson lookup. Use when a list row needs to check just one
/// lesson — keeps the row build cheap.
final ProviderFamily<bool, String> isLessonCompletedProvider =
    Provider.family<bool, String>((Ref ref, String lessonId) {
  return ref.watch(completedLessonsProvider).maybeWhen(
        data: (set) => set.contains(lessonId),
        orElse: () => false,
      );
});
