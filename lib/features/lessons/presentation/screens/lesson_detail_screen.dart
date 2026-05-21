import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/buttons/primary_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../data/lesson_models.dart';
import '../providers/lesson_providers.dart';
import '../widgets/learn_pill.dart';
import '../widgets/track_style.dart';

class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({
    super.key,
    required this.sectionId,
    required this.lessonId,
  });

  final String sectionId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LessonLookup? lookup = ref.watch(
      learnLessonByIdsProvider(
        (sectionId: sectionId, lessonId: lessonId),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: Text(lookup?.section.title ?? 'Lesson'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(RoutePaths.lessonsSectionFor(sectionId)),
        ),
      ),
      body: lookup == null
          ? const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Lesson not found',
              message: 'This lesson may have been moved or removed.',
            )
          : _Body(section: lookup.section, lesson: lookup.lesson),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.section, required this.lesson});
  final LearnSection section;
  final LearnLesson lesson;

  String get _whyItMatters {
    final String t = lesson.title.toLowerCase();
    if (t.contains('risk')) {
      return 'Risk management keeps one bad trade from damaging your account.';
    }
    if (t.contains('rsi') || t.contains('macd')) {
      return 'Indicators help confirm momentum before entering a trade.';
    }
    if (t.contains('support') || t.contains('resistance')) {
      return 'Support and resistance help identify where price may react.';
    }
    if (t.contains('option') ||
        t.contains('call') ||
        t.contains('put')) {
      return 'Understanding options helps you follow alerts with confidence.';
    }
    if (t.contains('flag') || t.contains('setup')) {
      return 'Clean setups help you avoid random entries and trade with a plan.';
    }
    return 'This concept directly impacts entries, exits, and trade discipline.';
  }

  String get _howToUse =>
      'Use this concept before entering a trade. Confirm the setup, check risk, '
      'understand the alert, and avoid chasing weak entries.';

  String get _keyTakeaway => lesson.bullets.isNotEmpty
      ? lesson.bullets.first
      : 'Trade with a plan, manage risk, and stay disciplined.';

  @override
  Widget build(BuildContext context) {
    final TrackStyle ts = TrackStyle.forTrack(section.track);
    final Color accent = lesson.featured ? AppColors.gold : ts.color;
    final TextTheme tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        FadeSlideIn(
          child: PremiumCard(
            accent: lesson.featured
                ? PremiumCardAccent.gold
                : PremiumCardAccent.none,
            glow: lesson.featured,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (lesson.featured) ...<Widget>[
                  const LearnPill(
                    label: 'Featured lesson',
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: 10),
                ],
                Text(lesson.title, style: tt.headlineSmall),
                const SizedBox(height: 8),
                Text(lesson.summary, style: tt.bodyLarge),
              ],
            ),
          ),
        ),
        if (lesson.imageAssetPath != null &&
            lesson.imageAssetPath!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _LessonImageCard(lesson: lesson, accent: AppColors.info),
          ),
        ],
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 90),
          child: _InfoCard(
            title: 'Why this matters',
            content: _whyItMatters,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 130),
          child: _KeyPointsCard(bullets: lesson.bullets),
        ),
        if (lesson.body != null && lesson.body!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          FadeSlideIn(
            delay: const Duration(milliseconds: 170),
            child: _InfoCard(
              title: 'Detailed notes',
              content: lesson.body!,
              color: AppColors.info,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 210),
          child: _InfoCard(
            title: 'How to use this in a trade',
            content: _howToUse,
            color: AppColors.bullish,
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: _InfoCard(
            title: 'Key takeaway',
            content: _keyTakeaway,
            color: accent,
          ),
        ),
        const SizedBox(height: 22),
        FadeSlideIn(
          delay: const Duration(milliseconds: 280),
          child: PrimaryButton(
            label: 'MARK COMPLETE',
            icon: Icons.check_circle_outline,
            onPressed: () =>
                context.showSnack('Lesson marked complete'),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.content,
    required this.color,
  });
  final String title;
  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(content, style: tt.bodyLarge),
        ],
      ),
    );
  }
}

class _KeyPointsCard extends StatelessWidget {
  const _KeyPointsCard({required this.bullets});
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'KEY POINTS',
            style: TextStyle(
              color: AppColors.bullish,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (bullets.isEmpty)
            Text('No key points yet.', style: tt.bodyMedium)
          else
            ...bullets.map(
              (String b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.bullish,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: tt.bodyLarge)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonImageCard extends StatelessWidget {
  const _LessonImageCard({required this.lesson, required this.accent});
  final LearnLesson lesson;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (lesson.imageTitle != null &&
              lesson.imageTitle!.trim().isNotEmpty) ...<Widget>[
            Text(
              lesson.imageTitle!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              lesson.imageAssetPath!,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (BuildContext c, _, __) => Container(
                height: 140,
                alignment: Alignment.center,
                color: AppColors.carbon,
                child: const Text(
                  'Image asset not bundled yet.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
