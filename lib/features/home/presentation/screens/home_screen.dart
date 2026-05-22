import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/asset_paths.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../alerts/presentation/providers/alerts_providers.dart';
import '../../../alerts/presentation/widgets/hot_trade_card.dart';
import '../../../scanner/presentation/widgets/scanner_card_skeleton.dart';
import '../providers/home_providers.dart';
import '../widgets/desk_performance_card.dart';
import '../widgets/event_timeline_card.dart';
import '../widgets/market_pulse_card.dart';
import '../widgets/market_regime_strip.dart';
import '../widgets/news_ticker_card.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/sector_heatmap_card.dart';
import '../widgets/vix_gauge_card.dart';

/// Customer home screen.
///
/// Layout (preserves the original premium design — header art, brand palette,
/// FadeSlideIn animations — and layers new market context widgets in):
///
///   1. ScreenHeader  (your brand header art, unchanged)
///   2. MarketPulseCard  (SPY/QQQ/DIA pulse, unchanged)
///   3. MarketRegimeStrip  ⟵ NEW: regime badge + open/close countdown
///   4. VixGaugeCard       ⟵ NEW: volatility gauge with color zones
///   5. SectorHeatmapCard  ⟵ NEW: 11-sector GICS grid
///   6. QuickActionGrid   (your existing nav grid, unchanged)
///   7. Hot Trades preview (unchanged)
///
/// Scanner preview removed by request — scanners now live only on the
/// Scanner tab.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(appUserProvider);
    final AsyncValue<List<TradeAlert>> hotAsync = ref.watch(hotAlertsProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.graphite,
        onRefresh: () async {
          ref.invalidate(hotAlertsProvider);
          ref.invalidate(homeOverviewStreamProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const ScreenHeader(asset: AssetPaths.headerHome),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: _HomeBody(userAsync: userAsync, hotAsync: hotAsync),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.userAsync, required this.hotAsync});

  final AsyncValue<AppUser?> userAsync;
  final AsyncValue<List<TradeAlert>> hotAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ---- Existing: Market Pulse ----
        FadeSlideIn(
          child: MarketPulseCard(
            displayName: userAsync.asData?.value?.displayName,
          ),
        ),
        const SizedBox(height: 14),

        // ---- New layer 1: regime badge + market countdown ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 60),
          child: MarketRegimeStrip(),
        ),
        const SizedBox(height: 12),

        // ---- New layer 2: VIX gauge ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 100),
          child: VixGaugeCard(),
        ),
        const SizedBox(height: 12),

        // ---- New layer 3: Sector heatmap ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 140),
          child: SectorHeatmapCard(),
        ),
        const SizedBox(height: 12),

        // ---- New layer 4: Desk performance ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 160),
          child: DeskPerformanceCard(),
        ),
        const SizedBox(height: 12),

        // ---- New layer 5: Today's economic events ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 180),
          child: EventTimelineCard(),
        ),
        const SizedBox(height: 12),

        // ---- New layer 6: Market news ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 200),
          child: NewsTickerCard(),
        ),
        const SizedBox(height: 18),

        // ---- Existing: Quick actions ----
        const FadeSlideIn(
          delay: Duration(milliseconds: 220),
          child: QuickActionGrid(),
        ),
        const SizedBox(height: 22),

        // ---- Existing: Hot trades preview ----
        FadeSlideIn(
          delay: const Duration(milliseconds: 260),
          child: SectionHeader(
            eyebrow: 'Curated',
            title: 'Hot Trades',
            action: TextButton(
              onPressed: () => context.go(RoutePaths.hotTrades),
              child: const Text('View all'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        hotAsync.when(
          loading: () => const ScannerCardSkeleton(),
          error: (Object e, _) => ErrorState(
            message: 'Could not load hot trades.',
            details: e.toString(),
            onRetry: () => ref.invalidate(hotAlertsProvider),
          ),
          data: (List<TradeAlert> alerts) {
            if (alerts.isEmpty) {
              return const EmptyState(
                icon: Icons.local_fire_department_outlined,
                title: 'No hot trades right now',
                message: 'Check back soon - the desk publishes here first.',
              );
            }
            final TradeAlert featured = alerts.first;
            return FadeSlideIn(
              delay: const Duration(milliseconds: 260),
              child: HotTradeCard(
                alert: featured,
                onOpenDetail: () =>
                    context.go(RoutePaths.alertDetailFor(featured.id)),
              ),
            );
          },
        ),
      ],
    );
  }
}
