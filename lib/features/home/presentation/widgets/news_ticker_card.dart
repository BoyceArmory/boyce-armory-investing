import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/home_providers.dart';

/// Premium market news card.
///
/// Layout (May 2026 rewrite — fixes "news cut off on phone" bug):
///   - The `news.png` banner artwork sits at the top of the card with a
///     fixed aspect ratio. Width drives its height via AspectRatio (no more
///     BoxFit.contain inside a min-height container, which previously
///     stretched the card to 560pt on small phones and pushed the news list
///     off-screen).
///   - The news list sits below the banner in a normal Column. Card height
///     naturally matches the content — no fixed minimum, no overlap.
///
/// On iPad / wide screens the surrounding ResponsiveContainer keeps the
/// card capped at 700pt so the banner doesn't blow up disproportionately.
class NewsTickerCard extends ConsumerWidget {
  const NewsTickerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);

    return async.maybeWhen(
      data: (o) {
        if (o.news.isEmpty) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.steel),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Banner artwork — width-driven, aspect-locked. The 16:5
                // ratio matches the visible header of news.png; if the asset
                // changes shape, retune the ratio here.
                AspectRatio(
                  aspectRatio: 16 / 5,
                  child: Image.asset(
                    'assets/backgrounds/news.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.graphite,
                      alignment: Alignment.center,
                      child: const Text(
                        'MARKET NEWS',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
                // News list — bounded by parent width, no overflow risk.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final n in o.news.take(5))
                        _NewsRow(
                          headline: n.headline,
                          source: n.source,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// One news row inside the card. Pulled out so the card body stays readable.
class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.headline, required this.source});
  final String headline;
  final String? source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.steel.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 6, right: 10),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (source != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      source!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
