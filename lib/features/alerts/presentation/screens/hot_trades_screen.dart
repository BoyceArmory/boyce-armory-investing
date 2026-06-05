import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_alert_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/responsive_container.dart';
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
  List<TradeAlert> _filter(List<TradeAlert> all) {
    final int idx = _tabs.index;
    switch (idx) {
      case 0:
        return all;
      case _zeroDteTabIndex:
        return all
            .where((TradeAlert a) => a.contract?.isZeroDte == true)
            .toList(growable: false);
      case 2:
        return all
            .where((TradeAlert a) => a.mode == ScannerMode.day)
            .toList(growable: false);
      case 3:
        return all
            .where((TradeAlert a) => a.mode == ScannerMode.swing)
            .toList(growable: false);
      case 4:
        return all
            .where((TradeAlert a) => a.mode == ScannerMode.leaps)
            .toList(growable: false);
      default:
        return all;
    }
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    "The team's highest-conviction setups, hand-picked from the scanner.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                _ModeTabs(controller: _tabs, labels: _tabLabels),
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
                      final List<TradeAlert> shown = _filter(all);
                      if (shown.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          children: <Widget>[
                            EmptyAlertCard(
                              eyebrow: _emptyEyebrow(),
                              title: _emptyTitle(),
                              message: _emptyMessage(),
                              icon: _emptyIcon(),
                            ),
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
