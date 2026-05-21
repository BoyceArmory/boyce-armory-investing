import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lesson_content.dart';
import '../../data/lesson_models.dart';

/// Source of all learn sections. Static today; swap to Firestore later.
final Provider<List<LearnSection>> learnSectionsProvider =
    Provider<List<LearnSection>>((Ref ref) => learnSections);

/// One section by id (null if missing).
final ProviderFamily<LearnSection?, String> learnSectionByIdProvider =
    Provider.family<LearnSection?, String>((Ref ref, String id) {
  final List<LearnSection> all = ref.watch(learnSectionsProvider);
  for (final LearnSection s in all) {
    if (s.id == id) return s;
  }
  return null;
});

class LessonLookup {
  const LessonLookup({required this.section, required this.lesson});
  final LearnSection section;
  final LearnLesson lesson;
}

/// Look up a lesson by (sectionId, lessonId). Returns null if either is missing.
final ProviderFamily<LessonLookup?, ({String sectionId, String lessonId})>
    learnLessonByIdsProvider = Provider.family<LessonLookup?,
        ({String sectionId, String lessonId})>(
  (Ref ref, ({String sectionId, String lessonId}) ids) {
    final LearnSection? s =
        ref.watch(learnSectionByIdProvider(ids.sectionId));
    if (s == null) return null;
    final LearnLesson? l = s.lessonById(ids.lessonId);
    if (l == null) return null;
    return LessonLookup(section: s, lesson: l);
  },
);
