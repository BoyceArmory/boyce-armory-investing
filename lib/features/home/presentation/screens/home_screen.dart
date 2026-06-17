import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../../../shared/widgets/push_permission_banner.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../../../shared/widgets/snooze_indicator_strip.dart';
import '../../../../shared/widgets/whats_new_banner.dart';
import '../../../alerts/presentation/providers/alerts_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/desk_performance_card.dart';
import '../widgets/event_timeline_card.dart';
import '../widgets/iv_rank_card.dart';
import '../widgets/lesson_of_day_card.dart';
import '../widgets/market_pulse_card.dart';
import '../widgets/market_regime_strip.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/sector_heatmap_card.dart';
import '../widgets/vix_gauge_card.dart';

/// Customer home screen.
///
/// Layout (May 2026 rework):
///
///   1. ScreenHeader              (brand header art)
///   2. DeskPerformanceCard       (track record card — MOVED UP, was below)
///   3. MarketPulseCard           (SPY / QQQ / DIA strip)
///   4. QuickActionGrid           (Hot Trades / Scanner / Premarket / Chat /
///                                 Learn — MOVED ABOVE the heatmap)
///   5. MarketRegimeStrip         (regime + countdown)
///   6. VixGaugeCard              (volatility gauge)
///   7. SectorHeatmapCard         (11-sector grid)
///   8. EventTimelineCard         (today's economic events)
///   9. NewsTickerCard            (market news)
///
/// Hot Trades preview section is intentionally REMOVED from home; the
/// dedicated Hot Trades tab + quick-action button cover that need without
/// duplicating content on home.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(appUserProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.graphite,
        onRefresh: () async {
          ref.invalidate(hotAlertsProvider);
          ref.invalidate(homeOverviewStreamProvider);
          ref.invalidate(ivRankSummaryProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const ScreenHeader(asset: AssetPaths.headerHome),
            ResponsiveContainer(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: _HomeBody(userAsync: userAsync),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.userAsync});

  final AsyncValue<AppUser?> userAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ---- Push permission banner. Renders nothing when permission
        // is granted; renders a red CTA when OS-blocked while the user's
        // master pref says ON (i.e. user wants pushes but they're not
        // arriving because iOS Settings has them off).
        const PushPermissionBanner(),
        const SizedBox(height: 8),
        // ---- What's-new banner — auto-hides when the user dismisses it
        // OR after they have already viewed/dismissed the v2.4.0 tip on
        // any device. Internally guards via isTipDismissedProvider.
        const WhatsNewBanner(),
        // The banner has its own internal padding; the snooze strip needs
        // a spacer when the banner is present, but conditionally adding
        // SizedBox would force WhatsNewBanner.build to expose its own
        // dismissed state. Simpler: always add 8pt — when the banner
        // collapses to SizedBox.shrink it's invisible anyway, the gap is
        // negligible and the layout stays stable across show/hide.
        const SizedBox(height: 8),
        // ---- Snooze indicator (only renders when armed).
        // Tap routes to /settings so the user can extend or cancel from
        // the same screen where they originally snoozed.
        const SnoozeIndicatorStrip(),
        const SizedBox(height: 12),

        // ---- Desk performance — MOVED to top of feed per May 2026 rework
        const FadeSlideIn(
          child: DeskPerformanceCard(),
        ),
        const SizedBox(height: 14),

        // ---- Market pulse (SPY / QQQ / DIA)
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: MarketPulseCard(
            displayName: userAsync.asData?.value?.displayName,
          ),
        ),
        const SizedBox(height: 18),

        // ---- Quick actions — MOVED above the heatmap per May 2026 rework
        const FadeSlideIn(
          delay: Duration(milliseconds: 100),
          child: QuickActionGrid(),
        ),
        const SizedBox(height: 22),

        // ---- Regime strip
        const FadeSlideIn(
          delay: Duration(milliseconds: 140),
          child: MarketRegimeStrip(),
        ),
        const SizedBox(height: 12),

        // ---- VIX gauge
        const FadeSlideIn(
          delay: Duration(milliseconds: 180),
          child: VixGaugeCard(),
        ),
        const SizedBox(height: 12),

        // ---- IV Rank tile (SPY/QQQ/IWM at-a-glance)
        const FadeSlideIn(
          delay: Duration(milliseconds: 200),
          child: IvRankCard(),
        ),
        const SizedBox(height: 12),

        // ---- Sector heatmap
        const FadeSlideIn(
          delay: Duration(milliseconds: 220),
          child: SectorHeatmapCard(),
        ),
        const SizedBox(height: 12),

        // ---- Today's economic events
        const FadeSlideIn(
          delay: Duration(milliseconds: 260),
          child: EventTimelineCard(),
        ),
        const SizedBox(height: 12),

        // ---- Lesson of the Day (closes out the feed with educational tile)
        const FadeSlideIn(
          delay: Duration(milliseconds: 300),
          child: LessonOfDayCard(),
        ),
        // News widget moved to its own /news route — accessible via the
        // "News" tile in the Quick Action grid above. Keeps home feed lean
        // and resolves the cut-off bug on shorter phones where the news
        // banner-overlay layout was forcing 560pt minimum height.
      ],
    );
  }
}

