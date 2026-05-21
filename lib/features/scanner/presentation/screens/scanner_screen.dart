import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/scanner_alert_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../providers/scanner_providers.dart';
import '../widgets/scanner_alert_card.dart';
import '../widgets/scanner_card_skeleton.dart';

/// 4-tab scanner screen: All / Day / Swing / LEAPS.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _adminView = false;

  /// Tab index 0 = All (no mode filter), 1/2/3 = day/swing/leaps.
  static const List<ScannerMode?> _tabModes = <ScannerMode?>[
    null,
    ScannerMode.day,
    ScannerMode.swing,
    ScannerMode.leaps,
  ];

  static const List<String> _tabLabels = <String>['All', 'Day', 'Swing', 'LEAPS'];

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
    final ScannerMode? mode = _tabModes[_tabs.index];
    if (_adminView && ref.read(isAdminProvider)) {
      return mode == null
          ? ref.watch(adminScannerResultsProvider)
          : ref.watch(adminScannerResultsByModeProvider(mode));
    }
    return mode == null
        ? ref.watch(publicScannerAlertsProvider)
        : ref.watch(publicScannerAlertsByModeProvider(mode));
  }

  String _emptyTitleFor(ScannerMode? mode) {
    if (mode == null) return 'No setups yet';
    return switch (mode) {
      ScannerMode.day =>
        'Day scanner is quiet',
      ScannerMode.swing => 'No swing setups yet',
      ScannerMode.leaps => 'No LEAPS candidates yet',
    };
  }

  String _emptyMessageFor(ScannerMode? mode) {
    if (mode == null) {
      return 'The scanner publishes here in real time. Pull to refresh.';
    }
    return switch (mode) {
      ScannerMode.day =>
        'Day mode scans every 5 minutes between 09:30 and 13:30 ET on the top 10 tickers. Outside that window it stays quiet.',
      ScannerMode.swing =>
        'Swing mode runs every 30 minutes during market hours on a broader large-cap universe.',
      ScannerMode.leaps =>
        'LEAPS mode runs once daily after close on long-uptrend candidates. Not a real-time alert source.',
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
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SectionHeader(
                eyebrow: 'Scanner',
                title: _adminView && isAdmin ? 'All Setups' : 'Live Setups',
                action: isAdmin
                    ? _AdminToggle(
                        adminView: _adminView,
                        onChanged: (bool v) =>
                            setState(() => _adminView = v),
                      )
                    : null,
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
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.6,
                            child: EmptyState(
                              icon: mode == ScannerMode.day
                                  ? Icons.bolt
                                  : mode == ScannerMode.leaps
                                      ? Icons.calendar_month_outlined
                                      : Icons.radar,
                              title: _emptyTitleFor(mode),
                              message: _emptyMessageFor(mode),
                            ),
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
