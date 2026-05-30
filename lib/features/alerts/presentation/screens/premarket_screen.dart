import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_alert_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../scanner/presentation/widgets/scanner_card_skeleton.dart';
import '../providers/alerts_providers.dart';
import '../widgets/hot_trade_card.dart';

/// Premarket Watchlist — the morning ritual screen.
///
/// Backend job `premarket-scan` runs at 9:25 AM ET, Mon-Fri:
///   1. Scans ~80 high-volatility tickers
///   2. Ranks by gap % * premarket volume * news catalyst
///   3. Writes the top 20 to `trade_alerts` with kind="premarket_watchlist"
///   4. Fires an FCM push so users open the app right at 9:25 ET
///
/// This screen renders those cards using the same `HotTradeCard` artwork
/// (bull_call_bg / bear_put_bg) so the visual language stays consistent.
/// Outside premarket hours the watchlist is naturally empty — the
/// EmptyAlertCard explains the schedule rather than appearing broken.
class PremarketScreen extends ConsumerWidget {
  const PremarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TradeAlert>> async =
        ref.watch(premarketAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.graphite,
        onRefresh: () async => ref.invalidate(premarketAlertsProvider),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => context.go(RoutePaths.home),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.gold),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'PREMARKET WATCHLIST',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Top movers ranked at 9:25 AM ET each weekday — gap %, premarket volume, and news catalyst.',
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
                    childCount: 4,
                  ),
                ),
              ),
              error: (Object e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: 'Could not load premarket watchlist.',
                  details: e.toString(),
                  onRetry: () =>
                      ref.invalidate(premarketAlertsProvider),
                ),
              ),
              data: (List<TradeAlert> alerts) {
                if (alerts.isEmpty) {
                  return const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: EmptyAlertCard(
                        eyebrow: 'WATCHLIST OFFLINE',
                        title: 'No premarket setups yet',
                        message:
                            "Premarket scanner fires every weekday at 9:25 AM ET. Top movers land here automatically — you'll get a push when the watchlist is ready.",
                        icon: Icons.wb_twilight,
                      ),
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
