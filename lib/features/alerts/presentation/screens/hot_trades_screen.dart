import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../scanner/presentation/widgets/scanner_card_skeleton.dart';
import '../providers/alerts_providers.dart';
import '../widgets/hot_trade_card.dart';

class HotTradesScreen extends ConsumerWidget {
  const HotTradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TradeAlert>> async = ref.watch(hotAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.graphite,
        onRefresh: () async => ref.invalidate(hotAlertsProvider),
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  eyebrow: 'Curated',
                  title: 'Hot Trades',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "The team's highest-conviction setups, hand-picked from the scanner.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            async.when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext c, int i) => const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: ScannerCardSkeleton(),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (Object e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: 'Could not load hot trades.',
                  details: e.toString(),
                  onRetry: () => ref.invalidate(hotAlertsProvider),
                ),
              ),
              data: (List<TradeAlert> alerts) {
                if (alerts.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.local_fire_department_outlined,
                      title: 'No hot trades right now',
                      message:
                          "When the team promotes a setup, it'll appear here first.",
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext c, int i) {
                        final TradeAlert a = alerts[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 30 * i),
                            child: HotTradeCard(
                              alert: a,
                              onOpenDetail: () => context.go(
                                RoutePaths.alertDetailFor(a.id),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: alerts.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
