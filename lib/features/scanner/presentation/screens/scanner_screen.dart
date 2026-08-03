import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/scanner_alert_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_alert_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../../../shared/widgets/snooze_indicator_strip.dart';
import '../providers/scanner_providers.dart';
import '../widgets/scanner_alert_card.dart';
import '../widgets/scanner_card_skeleton.dart';

/// 4-tab scanner screen: All / Day / Swing / LEAPS. All three channels are
/// TradingView-sourced (August 2026) — a Pine Script strategy posts a
/// webhook per setup, the backend maps it straight into this same
/// ScannerAlert shape by chart timeframe (intraday -> day, daily -> swing,
/// weekly -> leaps). See backend/src/controllers/webhook.controller.ts and
/// tradingview/boyce_armory_trend_pullback.pine.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _adminView = false;

  /// Tab modes per index: All / Day / Swing / LEAPS.
  static const List<ScannerMode?> _tabModes = <ScannerMode?>[
    null,               // All
    ScannerMode.day,
    ScannerMode.swing,
    ScannerMode.leaps,
  ];

  static const List<String> _tabLabels = <String>[
    'All',
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

  AsyncValue<List<ScannerAlert>> _watchForCurrentTab() {
    final int tabIndex = _tabs.index;
    final ScannerMode? mode = _tabModes[tabIndex];
    final bool useAdmin = _adminView && ref.read(isAdminProvider);

    if (useAdmin) {
      return mode == null
          ? ref.watch(adminScannerResultsProvider)
          : ref.watch(adminScannerResultsByModeProvider(mode));
    }
    return mode == null
        ? ref.watch(publicScannerAlertsProvider)
        : ref.watch(publicScannerAlertsByModeProvider(mode));
  }

  String _emptyEyebrowFor(ScannerMode? mode) {
    if (mode == null) return 'NO ACTIVE SETUPS';
    return switch (mode) {
      ScannerMode.day => 'DAY CHANNEL QUIET',
      ScannerMode.swing => 'SWING CHANNEL QUIET',
      ScannerMode.leaps => 'LEAPS CHANNEL QUIET',
    };
  }

  String _emptyTitleFor(ScannerMode? mode) {
    if (mode == null) return 'No setups firing right now';
    return switch (mode) {
      ScannerMode.day => 'No day setups',
      ScannerMode.swing => 'No swing setups',
      ScannerMode.leaps => 'No LEAPS candidates',
    };
  }

  String _emptyMessageFor(ScannerMode? mode) {
    if (mode == null) {
      return 'Setups call out here automatically as they fire on TradingView. Pull down to refresh, or check back during US market hours (9:30 AM – 4:00 PM ET).';
    }
    return switch (mode) {
      ScannerMode.day =>
        'Day setups call out intraday during market hours as the trend-pullback strategy fires on the 5–15 minute charts. Held same session.',
      ScannerMode.swing =>
        'Swing setups call out on the daily chart as the trend-pullback strategy fires. Held 1–10 days.',
      ScannerMode.leaps =>
        'LEAPS setups call out on the weekly chart — long-dated, multi-month trend continuation. Quiet by design.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ref.watch(isAdminProvider);
    final AsyncValue<List<ScannerAlert>> async = _watchForCurrentTab();
    final ScannerMode? mode = _tabModes[_tabs.index];

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        bottom: false,
        child: ResponsiveContainer(
          child: Column(
          children: <Widget>[
            // Branded image header — replaces the old SectionHeader.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Image.asset(
                'assets/buttons/scanner_button.png',
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
            // Persistent snooze chip — same compact variant as Hot Trades.
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: SnoozeIndicatorStrip(compact: true),
            ),
            // Admin Public/All toggle stays as its own row below the banner
            // so the brand image isn't competing with controls.
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _AdminToggle(
                    adminView: _adminView,
                    onChanged: (bool v) => setState(() => _adminView = v),
                  ),
                ),
              ),
            _ModeTabs(controller: _tabs, labels: _tabLabels),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.graphite,
                onRefresh: () async {
                  ref.invalidate(publicScannerAlertsProvider);
                  ref.invalidate(adminScannerResultsProvider);
                  for (final ScannerMode m in ScannerMode.values) {
                    ref.invalidate(publicScannerAlertsByModeProvider(m));
                    ref.invalidate(adminScannerResultsByModeProvider(m));
                  }
                },
                child: async.when(
                  loading: () => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, __) => const ScannerCardSkeleton(),
                  ),
                  error: (Object e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.6,
                        child: ErrorState(
                          message: 'Could not load scanner alerts.',
                          details: e.toString(),
                          onRetry: () => ref
                              .invalidate(publicScannerAlertsProvider),
                        ),
                      ),
                    ],
                  ),
                  data: (List<ScannerAlert> alerts) {
                    if (alerts.isEmpty) {
                      // Right-aligned dummy card that mirrors a real scanner
                      // card layout. Tells the user *why* the page is empty
                      // (market hours, scanner cadence) so an empty Scanner
                      // tab never feels broken to a reviewer or new user.
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: <Widget>[
                          EmptyAlertCard(
                            eyebrow: _emptyEyebrowFor(mode),
                            title: _emptyTitleFor(mode),
                            message: _emptyMessageFor(mode),
                            icon: switch (mode) {
                              ScannerMode.leaps =>
                                Icons.calendar_month_outlined,
                              ScannerMode.day => Icons.bolt_outlined,
                              _ => Icons.radar_outlined,
                            },
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (BuildContext c, int i) {
                        final ScannerAlert a = alerts[i];
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 30 * i),
                          child: ScannerAlertCard(
                            alert: a,
                            onOpenDetail: () => context.go(
                              RoutePaths.scannerDetailFor(a.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

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

class _AdminToggle extends StatelessWidget {
  const _AdminToggle({required this.adminView, required this.onChanged});
  final bool adminView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.steel),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _segment('Public', !adminView, () => onChanged(false)),
          _segment('All', adminView, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: selected ? AppColors.gold : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}