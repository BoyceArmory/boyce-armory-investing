import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_alert_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../../../shared/widgets/snooze_indicator_strip.dart';
import '../../../../shared/widgets/watchlist_manager_sheet.dart';
import '../../../scanner/presentation/widgets/scanner_card_skeleton.dart';
import '../providers/alerts_providers.dart';
import '../widgets/hot_trade_card.dart';

/// 5-tab Hot Trades screen: All / 0DTE / Day / Swing / LEAPS — matches
/// the Scanner screen layout so users can filter promoted alerts the
/// same way they filter raw scanner output. 0DTE is a derived filter on
/// top of the day-mode slice, scoped to alerts whose suggested contract
/// expires today (SPY/QQQ/IWM/DIA index options + any other ticker whose
/// chain happens to have a same-day expiry).
class HotTradesScreen extends ConsumerStatefulWidget {
  const HotTradesScreen({super.key});

  @override
  ConsumerState<HotTradesScreen> createState() => _HotTradesScreenState();
}

class _HotTradesScreenState extends ConsumerState<HotTradesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// When true, the visible Hot Trades list is filtered to alerts whose
  /// symbol is in the user's watchlist. Layered on top of the mode tab —
  /// so "Day + Watchlist" shows only day-mode alerts in your watchlist.
  bool _watchlistOnly = false;

  // Index 1 is the derived 0DTE filter on top of the day slice. Index 0
  // shows everything; 2/3/4 are direct mode filters.
  static const int _zeroDteTabIndex = 1;
  static const List<String> _tabLabels = <String>[
    'All',
    '0DTE',
    'Day',
    'Swing',
    'LEAPS',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Apply the current tab's filter to the Hot Trades stream. All filtering
  /// happens client-side because the source stream (`hotAlertsProvider`)
  /// already pulls every promoted alert — slicing in memory keeps the
  /// Firestore query simple and avoids per-tab indexes.
  ///
  /// Watchlist filter is applied AFTER the mode filter so the two layer
  /// predictably: "Day tab + watchlist" == "day-mode alerts in your
  /// watchlist."
  List<TradeAlert> _filter(List<TradeAlert> all, Set<String> watchlist) {
    final int idx = _tabs.index;
    List<TradeAlert> filtered;
    switch (idx) {
      case 0:
        filtered = all;
        break;
      case _zeroDteTabIndex:
        filtered = all
            .where((TradeAlert a) => a.contract?.isZeroDte == true)
            .toList(growable: false);
        break;
      case 2:
        filtered = all
            .where((TradeAlert a) => a.mode == ScannerMode.day)
            .toList(growable: false);
        break;
      case 3:
        filtered = all
            .where((TradeAlert a) => a.mode == ScannerMode.swing)
            .toList(growable: false);
        break;
      case 4:
        filtered = all
            .where((TradeAlert a) => a.mode == ScannerMode.leaps)
            .toList(growable: false);
        break;
      default:
        filtered = all;
    }
    if (_watchlistOnly && watchlist.isNotEmpty) {
      filtered = filtered
          .where((TradeAlert a) =>
              watchlist.contains(a.symbol.toUpperCase()))
          .toList(growable: false);
    }
    return filtered;
  }

  String _emptyEyebrow() {
    switch (_tabs.index) {
      case _zeroDteTabIndex:
        return '0DTE TAB QUIET';
      case 2:
        return 'NO DAY PROMOTES';
      case 3:
        return 'NO SWING PROMOTES';
      case 4:
        return 'NO LEAPS PROMOTES';
      default:
        return 'NO HOT TRADES RIGHT NOW';
    }
  }

  String _emptyTitle() {
    switch (_tabs.index) {
      case _zeroDteTabIndex:
        return 'No 0DTE plays right now';
      case 2:
        return 'No day-mode promotes';
      case 3:
        return 'No swing-mode promotes';
      case 4:
        return 'No LEAPS-mode promotes';
      default:
        return 'No promoted setups';
    }
  }

  String _emptyMessage() {
    switch (_tabs.index) {
      case _zeroDteTabIndex:
        return 'Promoted same-day-expiry options plays appear here. New 0DTE setups land as soon as a SPY/QQQ/IWM/DIA alert hits A grade or higher during market hours.';
      case 2:
        return 'Promoted intraday setups land here once the scanner flags an A or A+ on a day-mode candidate.';
      case 3:
        return 'Promoted swing setups land here once the scanner flags an A+ on the multi-day universe.';
      case 4:
        return 'Promoted LEAPS land here on the rare strong long-dated thesis. Updates twice per session.';
      default:
        return "When the scanner promotes an A+ setup or the team hand-picks a play, it'll land here first. Pull down to refresh — new alerts appear automatically during US market hours.";
    }
  }

  IconData _emptyIcon() {
    switch (_tabs.index) {
      case _zeroDteTabIndex:
        return Icons.flash_on;
      case 2:
        return Icons.bolt_outlined;
      case 4:
        return Icons.calendar_month_outlined;
      default:
        return Icons.local_fire_department_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TradeAlert>> async = ref.watch(hotAlertsProvider);
    final Set<String> watchlist = ref.watch(watchlistProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.graphite,
          onRefresh: () async => ref.invalidate(hotAlertsProvider),
          child: ResponsiveContainer(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Image.asset(
                    'assets/buttons/hot_trades_button.png',
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
                // Persistent snooze chip — renders nothing when the user
                // isn't snoozed. Compact variant to keep the dense Hot
                // Trades layout breathing.
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: SnoozeIndicatorStrip(compact: true),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    "The team's highest-conviction setups, hand-picked from the scanner.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                _ModeTabs(controller: _tabs, labels: _tabLabels),
                const SizedBox(height: 6),
                _WatchlistFilterRow(
                  active: _watchlistOnly,
                  count: watchlist.length,
                  onToggle: () {
                    // If the user taps the chip while their watchlist is
                    // empty, open the manager so they understand why no
                    // cards show. Otherwise just flip the filter state.
                    if (watchlist.isEmpty) {
                      WatchlistManagerSheet.show(context);
                      return;
                    }
                    setState(() => _watchlistOnly = !_watchlistOnly);
                  },
                  onManage: () => WatchlistManagerSheet.show(context),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: async.when(
                    loading: () => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemCount: 3,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, __) => const ScannerCardSkeleton(),
                    ),
                    error: (Object e, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.6,
                          child: ErrorState(
                            message: 'Could not load hot trades.',
                            details: e.toString(),
                            onRetry: () => ref.invalidate(hotAlertsProvider),
                          ),
                        ),
                      ],
                    ),
                    data: (List<TradeAlert> all) {
                      final List<TradeAlert> shown = _filter(all, watchlist);
                      if (shown.isEmpty) {
                        // Watchlist filter on but empty result — guide the
                        // user to either turn it off or open the manager.
                        // Different copy from the generic "no hot trades"
                        // empty state so they understand what's happening.
                        final bool watchlistFilterCulled =
                            _watchlistOnly &&
                                watchlist.isNotEmpty &&
                                all.isNotEmpty;
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          children: <Widget>[
                            EmptyAlertCard(
                              eyebrow: watchlistFilterCulled
                                  ? 'WATCHLIST FILTER ON'
                                  : _emptyEyebrow(),
                              title: watchlistFilterCulled
                                  ? 'No hot trades on your watchlist'
                                  : _emptyTitle(),
                              message: watchlistFilterCulled
                                  ? 'None of the current hot trades match your watchlist tickers. Turn the Watchlist chip off above to see all hot trades, or tap "Manage" to edit your list.'
                                  : _emptyMessage(),
                              icon: watchlistFilterCulled
                                  ? Icons.star_border
                                  : _emptyIcon(),
                            ),
                            if (!watchlistFilterCulled) ...<Widget>[
                              const SizedBox(height: 14),
                              _ScannerScheduleHintCard(
                                modeIndex: _tabs.index,
                                zeroDteIndex: _zeroDteTabIndex,
                              ),
                            ],
                          ],
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (BuildContext c, int i) {
                          final TradeAlert a = shown[i];
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 30 * i),
                            child: HotTradeCard(
                              alert: a,
                              onOpenDetail: () => context.go(
                                RoutePaths.alertDetailFor(a.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact row between the mode tabs and the alert list. Shows the
/// "Watchlist" toggle chip + a Manage shortcut so the user can clean up
/// Schedule hint card paired with EmptyAlertCard on quiet days. Tells
/// the user when alerts are expected to fire so the empty state feels
/// intentional rather than broken. Copy varies per mode tab — day-mode
/// runs at a faster cadence, swing scans twice daily, LEAPS twice
/// daily on a slower window.
class _ScannerScheduleHintCard extends StatelessWidget {
  const _ScannerScheduleHintCard({
    required this.modeIndex,
    required this.zeroDteIndex,
  });
  final int modeIndex;
  final int zeroDteIndex;

  String get _line {
    if (modeIndex == zeroDteIndex) {
      return '0DTE scans every minute during the open. Plays land instantly when a same-day SPY / QQQ / IWM / DIA setup hits A grade or higher.';
    }
    switch (modeIndex) {
      case 2:
        return 'Day-mode scanner runs every minute from 9:30 AM to 1:30 PM ET. New A / A+ alerts auto-promote here.';
      case 3:
        return 'Swing-mode scanner runs at 10:00 AM and 3:30 PM ET. Promotes require A+ grade for multi-day setups.';
      case 4:
        return 'LEAPS scanner runs twice daily (10:30 AM, 2:30 PM ET). Long-dated A+ setups only — quiet by design.';
      default:
        return 'Scanner runs every minute during market hours and twice daily for swing / LEAPS. Promotes appear here automatically — pull down to refresh.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.schedule, color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _line,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// the list without leaving the screen. Active state is gold-filled;
/// inactive is steel outline.
class _WatchlistFilterRow extends StatelessWidget {
  const _WatchlistFilterRow({
    required this.active,
    required this.count,
    required this.onToggle,
    required this.onManage,
  });
  final bool active;
  final int count;
  final VoidCallback onToggle;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : AppColors.graphite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : AppColors.steel,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? Icons.star : Icons.star_border,
                    size: 14,
                    color: active
                        ? AppColors.gold
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Watchlist',
                    style: TextStyle(
                      color: active
                          ? AppColors.gold
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '· $count',
                      style: TextStyle(
                        color: active
                            ? AppColors.gold
                            : AppColors.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.tune,
                size: 14, color: AppColors.textSecondary),
            label: const Text(
              'Manage',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirror of the scanner_screen mode-tabs widget — same look, same feel,
/// just in a separate file so changes don't bleed across screens.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.controller, required this.labels});
  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.steel),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        tabs: <Widget>[for (final String l in labels) Tab(text: l)],
      ),
    );
  }
}
