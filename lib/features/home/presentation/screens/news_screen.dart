import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_alert_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../data/home_overview_model.dart';
import '../providers/home_providers.dart';

/// Dedicated market news screen.
///
/// Sourced from the same `homeOverviewStreamProvider` that powers the home
/// page's other market widgets, but rendered as a full scrollable list with
/// tappable headlines that open the source article in the system browser.
///
/// May 2026 rework — moved off the home feed (where it kept getting cut
/// off on shorter phones with the old banner-overlay layout) into its own
/// route accessed via the Quick Action grid.
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
              final news = o.news;
              if (news.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                  children: const <Widget>[
                    EmptyAlertCard(
                      eyebrow: 'NO NEWS YET',
                      title: 'Market news will land here',
                      message:
                          'Headlines refresh automatically alongside the rest of the home feed. Pull down to refresh.',
                      icon: Icons.article_outlined,
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                itemCount: news.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _NewsRow(item: news[i]),
              );
            },
          ),
        ),
      ),
    );
  }
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 6, right: 12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (item.source != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        item.source!.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new,
                color: AppColors.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
