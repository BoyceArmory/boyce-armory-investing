import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../lessons/data/lesson_models.dart';
import '../../../lessons/presentation/providers/lesson_providers.dart';

/// Lesson of the Day — a single curated lesson surfaced on home so users
/// see something new to learn every day even if they don't browse the
/// dedicated Learn tab. Picks deterministically per calendar day so the
/// same lesson is shown to everyone on the same UTC day and rotates at
/// midnight UTC.
class LessonOfDayCard extends ConsumerWidget {
  const LessonOfDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pick = ref.watch(lessonOfDayProvider);
    if (pick == null) return const SizedBox.shrink();

    final section = pick.section;
    final lesson = pick.lesson;
    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(
          RoutePaths.lessonsLessonFor(section.id, lesson.id),
        ),
        // Stack so the background art fills the card edge-to-edge while
        // a dark scrim keeps the lesson copy legible against any image
        // tonality. errorBuilder falls back to the original gradient so
        // an asset-missing/decoding error doesn't blank the card.
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                AssetPaths.bgPlainCard,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.graphite, AppColors.carbon],
                    ),
                  ),
                ),
              ),
            ),
            // Dark scrim: enough opacity to guarantee text contrast on
            // any background art without washing the art out entirely.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.steel),
              ),
              child: Column(
            // Center every row in the card so the lesson copy reads as a
            // poster, not a left-aligned list. Background art is also
            // visually centered so this keeps the composition balanced.
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eyebrow row: gold pill + section title, centered.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.55)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school,
                            size: 11, color: AppColors.gold),
                        SizedBox(width: 3),
                        Text('LESSON OF THE DAY',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Section title — Flexible (not Expanded) so it shares
                  // space with the pill but doesn't force the Row to
                  // stretch. Centered text-align so the eyebrow group
                  // reads as a centered unit.
                  Flexible(
                    child: Text(
                      section.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                lesson.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                lesson.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tap to read',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward,
                      size: 12, color: AppColors.gold),
                ],
              ),
            ],
          ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Result of picking a single lesson + the section it belongs to so the
/// card can show the section eyebrow and the navigation can route to
/// the full /lessons/section/{sectionId}/lesson/{lessonId} path.
class LessonPick {
  const LessonPick({required this.section, required this.lesson});
  final LearnSection section;
  final LearnLesson lesson;
}

/// Picks one lesson for the current calendar day. Deterministic across
/// users on the same day so the experience feels intentional rather
/// than random per-app-launch. Resets at midnight UTC.
final Provider<LessonPick?> lessonOfDayProvider =
    Provider<LessonPick?>((Ref ref) {
  final sections = ref.watch(learnSectionsProvider);
  // Flatten (section, lesson) pairs so the rotation walks every lesson
  // in the catalog, not just one per section.
  final pairs = <LessonPick>[];
  for (final section in sections) {
    for (final lesson in section.lessons) {
      pairs.add(LessonPick(section: section, lesson: lesson));
    }
  }
  if (pairs.isEmpty) return null;
  // Day-of-year as the seed. The catalog will outgrow 365 lessons
  // eventually but modulo keeps the index in bounds.
  final now = DateTime.now().toUtc();
  final dayOfYear =
      now.difference(DateTime.utc(now.year, 1, 1)).inDays;
  final idx = dayOfYear % pairs.length;
  return pairs[idx];
});
