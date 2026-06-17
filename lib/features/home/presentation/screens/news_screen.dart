import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_alert_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';

/// Dedicated market news screen.
///
/// Sourced from `homeOverviewStreamProvider` which pulls headlines from
/// Polygon's `/v2/reference/news` endpoint (general US-market news,
/// aggregated across Benzinga / Seeking Alpha / Reuters / MarketWatch /
/// Yahoo Finance / etc.). 25 items per fetch, cached server-side for ~10
/// minutes — pull-to-refresh forces an immediate re-pull from upstream.
///
/// Layout: grouped by recency bucket (Just now / Earlier today / Yesterday
/// / Older) so users can scan what's actually new vs. background context.
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeOverviewStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        title: const Text(
          'MARKET NEWS',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.home),
        ),
      ),
      body: ResponsiveContainer(
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.graphite,
          onRefresh: () async => ref.invalidate(homeOverviewStreamProvider),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
            error: (Object e, _) => ErrorState(
              message: 'Could not load news.',
              details: e.toString(),
              onRetry: () => ref.invalidate(homeOverviewStreamProvider),
            ),
            data: (o) {
              // Watchlist-rank: pin headlines whose text mentions a watchlisted
              // symbol to the top under a "FROM YOUR WATCHLIST" header. Falls
              // back to chronological-grouped view when nothing matches.
              // Substring match is brittle (e.g. "AAPL" matches "AAPL.B") but
              // close enough for a quick personalization win.
              final Set<String> watch = ref.watch(watchlistProvider);
              final List<NewsItem> watched = <NewsItem>[];
              final List<NewsItem> rest = <NewsItem>[];
              for (final NewsItem n in o.news) {
                final String hl = n.headline.toUpperCase();
                final bool hit = watch.any((String s) =>
                    RegExp(r'\b' + RegExp.escape(s) + r'\b').hasMatch(hl));
                if (hit) {
                  watched.add(n);
                } else {
                  rest.add(n);
                }
              }
              final news = rest;
              if (o.news.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: const <Widget>[
                    EmptyAlertCard(
                      eyebrow: 'NO NEWS YET',
                      title: 'Market news will land here',
                      message:
                          'Headlines refresh automatically every ~10 minutes from Polygon\'s news aggregator. Pull down to refresh manually.',
                      icon: Icons.article_outlined,
                    ),
                  ],
                );
              }
              final groups = _groupByRecency(news);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                children: <Widget>[
                  // Top meta: count + source disclosure so users know what
                  // they're looking at. Disambiguates from in-house desk
                  // calls vs. aggregated market news.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.bolt,
                            color: AppColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${news.length} headlines · auto-refresh ~10min',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Watchlist-pinned section. Only shown when at least one
                  // headline mentions a watchlisted ticker. Renders ABOVE the
                  // recency-grouped feed so users see their stuff first.
                  if (watched.isNotEmpty) ...<Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(6, 14, 6, 8),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.star,
                              color: AppColors.gold, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'FROM YOUR WATCHLIST',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final item in watched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NewsRow(item: item),
                      ),
                  ],
                  for (final group in groups) ...<Widget>[
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(6, 14, 6, 8),
                      child: Text(
                        group.label.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                    for (final item in group.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _NewsRow(item: item),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_NewsGroup> _groupByRecency(List<NewsItem> news) {
    final now = DateTime.now();
    final justNow = <NewsItem>[];
    final today = <NewsItem>[];
    final yesterday = <NewsItem>[];
    final older = <NewsItem>[];
    for (final n in news) {
      final t = n.time;
      if (t == null) {
        older.add(n);
        continue;
      }
      final diff = now.difference(t);
      if (diff.inMinutes < 30) {
        justNow.add(n);
      } else if (diff.inHours < 24 && t.day == now.day) {
        today.add(n);
      } else if (diff.inHours < 48 || t.day == now.subtract(const Duration(days: 1)).day) {
        yesterday.add(n);
      } else {
        older.add(n);
      }
    }
    final groups = <_NewsGroup>[];
    if (justNow.isNotEmpty) groups.add(_NewsGroup('Just now', justNow));
    if (today.isNotEmpty) groups.add(_NewsGroup('Earlier today', today));
    if (yesterday.isNotEmpty) groups.add(_NewsGroup('Yesterday', yesterday));
    if (older.isNotEmpty) groups.add(_NewsGroup('Older', older));
    return groups;
  }
}

class _NewsGroup {
  const _NewsGroup(this.label, this.items);
  final String label;
  final List<NewsItem> items;
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item});
  final NewsItem item;

  Future<void> _open() async {
    if (item.url.isEmpty) return;
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = item.time?.ago ?? '';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _open,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.steel),
          ),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 7, right: 12),
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
                      item.headline,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        if (item.source != null) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              item.source!.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.open_in_new,
                  color: AppColors.textTertiary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
