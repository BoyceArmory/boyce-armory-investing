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

/// 5-tab scanner screen: All / 0DTE / Day / Swing / LEAPS.
///
/// 0DTE is a derived view on top of the day-mode stream — it filters to
/// alerts whose suggested contract expires today (SPY/QQQ/IWM/DIA index
/// options + any other ticker that happens to have a 0DTE chain). The tab
/// is positioned right after All so customers see the highest-conviction
/// intraday options plays first.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _adminView = false;

  // Sentinel index for the 0DTE filter — it's a derived view on the day
  // stream, not a real ScannerMode. _watchForCurrentTab() special-cases
  // this index to apply the isZeroDte client-side filter.
  static const int _zeroDteTabIndex = 1;

  /// Tab modes per index. Index 1 is the 0DTE derived filter, index 2 is
  /// the explicit scalp mode (0DTE 5-min scanner, opt-in). _watchForCurrentTab
  /// special-cases the 0DTE index because it's a derived filter on the day
  /// stream; scalp uses its own backend stream because it has different
  /// detectors/cadence.
  static const List<ScannerMode?> _tabModes = <ScannerMode?>[
    null,               // All
    ScannerMode.day,    // 0DTE (filtered from day)
    ScannerMode.scalp,  // Scalp (real scalp-mode stream)
    ScannerMode.day,    // Day
    ScannerMode.swing,
    ScannerMode.leaps,
  ];

  static const List<String> _tabLabels = <String>[
    'All',
    '0DTE',
    'Scalp',
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

    // 0DTE tab: pull the day-mode stream and apply an in-memory filter
    // for alerts whose suggested contract expires today. This avoids a
    // separate backend endpoint — the data is already in the day stream,
    // we just slice it. Admin "All" toggle still works: it swaps the
    // upstream source to admin_only results before filtering.
    if (tabIndex == _zeroDteTabIndex) {
      final AsyncValue<List<ScannerAlert>> upstream = useAdmin
          ? ref.watch(adminScannerResultsByModeProvider(ScannerMode.day))
          : ref.watch(publicScannerAlertsByModeProvider(ScannerMode.day));
      return upstream.whenData(
        (List<ScannerAlert> alerts) => alerts
            .where((ScannerAlert a) => a.suggestedContract?.isZeroDte == true)
            .toList(growable: false),
      );
    }

    if (useAdmin) {
      return mode == null
          ? ref.watch(adminScannerResultsProvider)
          : ref.watch(adminScannerResultsByModeProvider(mode));
    }
    return mode == null
        ? ref.watch(publicScannerAlertsProvider)
        : ref.watch(publicScannerAlertsByModeProvider(mode));
  }

  bool get _isZeroDteTab => _tabs.index == _zeroDteTabIndex;

  String _emptyEyebrowFor(ScannerMode? mode) {
    if (_isZeroDteTab) return '0DTE TAB QUIET';
    if (mode == null) return 'NO ACTIVE SETUPS';
    return switch (mode) {
      ScannerMode.day => 'DAY SCANNER QUIET',
      ScannerMode.swing => 'SWING SCANNER QUIET',
      ScannerMode.leaps => 'LEAPS SCANNER QUIET',
      ScannerMode.scalp => 'SCALP SCANNER QUIET',
    };
  }

  String _emptyTitleFor(ScannerMode? mode) {
    if (_isZeroDteTab) return 'No 0DTE plays right now';
    if (mode == null) return 'No setups firing right now';
    return switch (mode) {
      ScannerMode.day => 'No day setups',
      ScannerMode.swing => 'No swing setups',
      ScannerMode.leaps => 'No LEAPS candidates',
      ScannerMode.scalp => 'No scalp setups',
    };
  }

  String _emptyMessageFor(ScannerMode? mode) {
    if (_isZeroDteTab) {
      return 'Same-day-expiry option setups appear here when the scanner fires on SPY / QQQ / IWM / DIA during market hours. New plays show up as soon as they trigger.';
    }
    if (mode == null) {
      return 'The live scanner publishes A+ setups here automatically. Pull down to refresh, or check back during US market hours (9:30 AM – 4:00 PM ET).';
    }
    return switch (mode) {
      ScannerMode.day =>
        'Day scanner runs every minute from 9:30 AM – 1:30 PM ET, Mon–Fri. New setups appear here as soon as they fire.',
      ScannerMode.swing =>
        'Swing scanner runs every 5 minutes during US market hours on the large-cap universe. Pull down to refresh.',
      ScannerMode.leaps =>
        'LEAPS scanner runs hourly during US market hours on long-uptrend candidates. Daily-candle setups update slowly by design.',
      ScannerMode.scalp =>
        '0DTE 5-min scalp scanner runs every 30s from 9:35 AM – 3:30 PM ET on SPY / QQQ / IWM / DIA + mega-caps. Alerts expire after 10 minutes — react fast.',
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
                            icon: _isZeroDteTab
                                ? Icons.flash_on
                                : mode == ScannerMode.day
                                    ? Icons.bolt_outlined
                                    : mode == ScannerMode.leaps
                                        ? Icons.calendar_month_outlined
                                        : Icons.radar_outlined,
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
          color: selected ? AppColors.gold.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
                                       