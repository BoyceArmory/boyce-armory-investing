import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/home_repository.dart';
import '../providers/home_providers.dart';

/// IV Rank tile — at-a-glance options-cheap-vs-expensive view for SPY,
/// QQQ, IWM. Rank in [0..100]: 0 = lowest IV in trailing 1y → prefer long
/// premium; 100 = highest IV in trailing 1y → prefer short premium /
/// spreads.
///
/// Empty state: when the backend hasn't enabled options data yet (no
/// historical IV collection), we show a single-line explainer instead of
/// blank rows. The card is silent when the request errors so a backend
/// outage doesn't poison the home screen.
class IvRankCard extends ConsumerWidget {
  const IvRankCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ivRankSummaryProvider);

    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(16),
      // clipBehavior so the background image respects the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tap behavior is contextual:
        //   - When values are visible, route to the IV lesson so users
        //     can interpret what they're seeing.
        //   - When the disabled / empty state is showing, also route to
        //     the lesson so the card isn't a dead surface.
        // Both paths land on `options/implied-volatility` in the Learn tab.
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(
          RoutePaths.lessonsLessonFor('options', 'implied-volatility'),
        ),
        // Stack so the plain background art fills the card behind a
        // dark scrim. errorBuilder falls back to plain graphite if the
        // asset isn't bundled yet.
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                AssetPaths.bgPlainCard,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            // Dark scrim — text is bright + light, scrim ensures contrast
            // on any background tonality.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.70),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.steel),
              ),
              child: Column(
            // Center every row so the card content reads as a poster on
            // top of the background art, matching the Lesson of the Day
            // composition.
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text('OPTIONS IV RANK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0)),
                  SizedBox(width: 8),
                  Text('1Y',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward,
                      size: 12, color: Colors.white),
                ],
              ),
              const SizedBox(height: 10),
              async.when(
                loading: () => const _Skeleton(),
                error: (_, __) => const _DisabledState(),
                data: (summary) {
                  if (!summary.enabled || summary.items.isEmpty) {
                    return const _DisabledState();
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < summary.items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _IvRow(item: summary.items[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Always-on footnote — tells users what tapping does so the
              // card never feels inert even on the disabled state.
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school,
                      size: 11, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Tap to learn how IV rank works',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
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

class _IvRow extends StatelessWidget {
  const _IvRow({required this.item});
  final IvRankItem item;

  /// Color rank bands so a glance at the card tells you the regime:
  /// <30 = cheap (bullish for long premium, color bullish),
  /// 30–70 = neutral,
  /// >70 = expensive (color bearish — prefer spreads or short premium).
  Color _color(double? rank) {
    if (rank == null) return AppColors.textTertiary;
    if (rank >= 70) return AppColors.bearish;
    if (rank <= 30) return AppColors.bullish;
    return AppColors.gold;
  }

  @override
  Widget build(BuildContext context) {
    final rank = item.rank;
    final color = _color(rank);
    final rankStr = rank == null ? '—' : rank.toStringAsFixed(0);
    final ivStr =
        item.iv == null ? '—' : (item.iv! * 100).toStringAsFixed(0);
    final pct = ((rank ?? 0) / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(item.ticker,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      color: AppColors.steel,
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 6,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('rk $rankStr',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text('iv $ivStr%',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 14,
        child: Center(
          child: SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.gold),
          ),
        ),
      ),
    );
  }
}

class _DisabledState extends StatelessWidget {
  const _DisabledState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'IV history collection not enabled yet. Once the backfill runs, '
        'SPY · QQQ · IWM rank will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.white, fontSize: 11.5, height: 1.4),
      ),
    );
  }
}
