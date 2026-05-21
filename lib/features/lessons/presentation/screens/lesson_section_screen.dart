import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../data/lesson_models.dart';
import '../providers/lesson_providers.dart';
import '../widgets/learn_pill.dart';
import '../widgets/track_style.dart';

class LessonSectionScreen extends ConsumerWidget {
  const LessonSectionScreen({super.key, required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LearnSection? section =
        ref.watch(learnSectionByIdProvider(sectionId));

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: Text(section?.title ?? 'Lessons'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.lessons),
        ),
      ),
      body: section == null
          ? const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Section not found',
              message: 'This learning path may have been moved or removed.',
            )
          : _Body(section: section),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.section});
  final LearnSection section;

  @override
  Widget build(BuildContext context) {
    final TrackStyle ts = TrackStyle.forTrack(section.track);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        FadeSlideIn(
          child: _SectionHeader(section: section, style: ts),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 70),
          child: const _QuickStartCard(),
        ),
        const SizedBox(height: 20),
        Text(
          'Lessons',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(section.lessons.length, (int i) {
          final LearnLesson l = section.lessons[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeSlideIn(
              delay: Duration(milliseconds: 100 + 40 * i),
              child: _LessonCard(
                section: section,
                lesson: l,
                style: ts,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section, required this.style});
  final LearnSection section;
  final TrackStyle style;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return PremiumCard(
      accent: PremiumCardAccent.none,
      child: Row(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: style.color.withValues(alpha: 0.4)),
            ),
            child: Icon(style.icon, color: style.color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(section.title, style: tt.titleLarge),
                const SizedBox(height: 4),
                Text(section.subtitle, style: tt.bodyMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    LearnPill(
                      label: '${section.lessons.length} lessons',
                      color: style.color,
                    ),
                    if (section.featuredCount > 0)
                      LearnPill(
                        label: '${section.featuredCount} featured',
                        color: AppColors.gold,
                      ),
                    const LearnPill(
                      label: 'Course path',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      accent: PremiumCardAccent.gold,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          const Icon(Icons.route, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Quick start path: learn the concept, understand why it matters, then apply it to live alerts.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.section,
    required this.lesson,
    required this.style,
  });
  final LearnSection section;
  final LearnLesson lesson;
  final TrackStyle style;

  String get _difficulty {
    final String t = '${lesson.title} ${lesson.summary}'.toLowerCase();
    if (lesson.featured) return 'Featured';
    if (t.contains('advanced') ||
        t.contains('greeks') ||
        t.contains('spread')) {
      return 'Advanced';
    }
    if (t.contains('basic') ||
        t.contains('beginner') ||
        t.contains('foundation')) {
      return 'Beginner';
    }
    return 'Core';
  }

  String get _time {
    final int n = lesson.bullets.length;
    if (n <= 3) return '3 min';
    if (n <= 6) return '5 min';
    return '7 min';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = lesson.featured ? AppColors.gold : style.color;
    final TextTheme tt = Theme.of(context).textTheme;

    return PremiumCard(
      accent: lesson.featured
          ? PremiumCardAccent.gold
          : PremiumCardAccent.none,
      onTap: () => context.go(
        RoutePaths.lessonsLessonFor(section.id, lesson.id),
      ),
      glow: lesson.featured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  lesson.featured ? Icons.star : Icons.play_arrow,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(lesson.title, style: tt.titleMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lesson.summary,
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              LearnPill(label: _difficulty, color: accent),
              const SizedBox(width: 6),
              const LearnPill(
                label: 'Quick read',
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              LearnPill(label: _time, color: AppColors.info),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  'START',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
