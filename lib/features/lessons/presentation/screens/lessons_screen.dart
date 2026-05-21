import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/premium_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../data/lesson_models.dart';
import '../providers/lesson_providers.dart';
import '../widgets/learn_pill.dart';
import '../widgets/track_style.dart';

/// Top-level Academy screen - lists every learning path.
class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LearnSection> _filter(List<LearnSection> all) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((LearnSection s) {
      final bool inSection = s.title.toLowerCase().contains(q) ||
          s.subtitle.toLowerCase().contains(q);
      final bool inLesson = s.lessons.any((LearnLesson l) =>
          l.title.toLowerCase().contains(q) ||
          l.summary.toLowerCase().contains(q));
      return inSection || inLesson;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<LearnSection> all = ref.watch(learnSectionsProvider);
    final List<LearnSection> sections = _filter(all);
    final int totalLessons =
        all.fold<int>(0, (int n, LearnSection s) => n + s.lessons.length);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: <Widget>[
            const SectionHeader(eyebrow: 'Education', title: 'Academy'),
            const SizedBox(height: 14),
            FadeSlideIn(
              child: _AcademyHeaderCard(
                totalPaths: all.length,
                totalLessons: totalLessons,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _SearchBox(
                controller: _searchController,
                onChanged: (String v) => setState(() => _query = v),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Learning paths',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (sections.isEmpty)
              const EmptyState(
                icon: Icons.search_off,
                title: 'No lessons match',
                message: 'Try searching a different trading concept.',
              )
            else
              ...List<Widget>.generate(sections.length, (int i) {
                final LearnSection s = sections[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 110 + 40 * i),
                    child: _LearningPathCard(section: s),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _AcademyHeaderCard extends StatelessWidget {
  const _AcademyHeaderCard({
    required this.totalPaths,
    required this.totalLessons,
  });

  final int totalPaths;
  final int totalLessons;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return PremiumCard(
      accent: PremiumCardAccent.gold,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Boyce Armory Academy',
            style: tt.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Learn the system. Trade with discipline.',
            style: tt.bodyMedium,
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  value: '$totalPaths',
                  label: 'Paths',
                  color: AppColors.bullish,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  value: '$totalLessons',
                  label: 'Lessons',
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _StatTile(
                  value: 'ALL',
                  label: 'Levels',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search lessons, setups, RSI, MACD…',
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClear,
              ),
      ),
    );
  }
}

class _LearningPathCard extends StatelessWidget {
  const _LearningPathCard({required this.section});
  final LearnSection section;

  @override
  Widget build(BuildContext context) {
    final TrackStyle ts = TrackStyle.forTrack(section.track);
    final TextTheme tt = Theme.of(context).textTheme;

    return PremiumCard(
      onTap: () =>
          context.go(RoutePaths.lessonsSectionFor(section.id)),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: ts.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ts.color.withValues(alpha: 0.4)),
            ),
            child: Icon(ts.icon, color: ts.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(section.title, style: tt.titleMedium),
                const SizedBox(height: 4),
                Text(
                  section.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    LearnPill(
                      label: '${section.lessons.length} lessons',
                      color: AppColors.bullish,
                    ),
                    if (section.featuredCount > 0) ...<Widget>[
                      const SizedBox(width: 6),
                      LearnPill(
                        label: '${section.featuredCount} featured',
                        color: AppColors.gold,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
