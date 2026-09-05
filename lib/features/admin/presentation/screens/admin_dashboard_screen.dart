import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/admin_providers.dart';
import '../widgets/alerts_tab.dart';
import '../widgets/analytics_tab.dart';
import '../widgets/audit_tab.dart';
import '../widgets/backtest_tab.dart';
import '../widgets/cooldowns_tab.dart';
import '../widgets/detectors_tab.dart';
import '../widgets/jobs_tab.dart';
import '../widgets/learning_tab.dart';
import '../widgets/push_tab.dart';
import '../widgets/scanner_ops_tab.dart';
import '../widgets/status_tab.dart';
import '../widgets/trades_tab.dart';
import '../widgets/users_tab.dart';

/// Admin dashboard — full ops control center, all slices live.
///
///   Status    — what's running (auto-refresh 30s).
///   Analytics — opens the web performance dashboard (equity curve,
///               strategy/mode/symbol/regime/session breakdowns, score
///               calibration, auto-generated insights) in an in-app
///               browser view. Lives on the backend, not natively, so it
///               can keep evolving without an app release — see
///               analytics_tab.dart.
///   Scanner   — manual trigger, run history, kill switches.
///   Alerts   — scanner alert visibility management.
///   Users    — list + role/tier/disabled controls.
///   Trades   — active (with close) + closed.
///   Audit    — admin_logs feed.
///
/// Backtest / Detectors / Learning are hidden while the backend's
/// MASSIVE_ENABLED flag is off (Aug 2026 — the TradingView webhook
/// pipeline drives every live signal now; the old multi-detector scanner
/// those three tabs describe produces nothing new while Massive is off,
/// so showing them would just be permanently-stale numbers). They
/// reappear automatically the moment Massive is re-enabled on the
/// backend — see `SystemStatus.massiveEnabled` / `_massiveOnlyLabels`.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _TabEntry {
  const _TabEntry(this.spec, this.widget, {this.massiveOnly = false});
  final _TabSpec spec;
  final Widget widget;
  final bool massiveOnly;
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _massiveEnabled = true;
  late List<_TabEntry> _visible;

  static const List<_TabEntry> _allTabs = <_TabEntry>[
    _TabEntry(_TabSpec('Status', Icons.monitor_heart_outlined), StatusTab()),
    _TabEntry(_TabSpec('Analytics', Icons.query_stats), AnalyticsTab()),
    _TabEntry(_TabSpec('Scanner', Icons.radar), ScannerOpsTab()),
    _TabEntry(_TabSpec('Alerts', Icons.campaign_outlined), AlertsTab()),
    _TabEntry(_TabSpec('Jobs', Icons.flash_on), JobsTab()),
    _TabEntry(_TabSpec('Push', Icons.notifications_active_outlined), PushTab()),
    _TabEntry(_TabSpec('Backtest', Icons.analytics_outlined), BacktestTab(),
        massiveOnly: true),
    _TabEntry(_TabSpec('Detectors', Icons.tune), DetectorsTab(), massiveOnly: true),
    _TabEntry(_TabSpec('Cooldowns', Icons.timer_outlined), CooldownsTab()),
    _TabEntry(_TabSpec('Learning', Icons.school_outlined), LearningTab(),
        massiveOnly: true),
    _TabEntry(_TabSpec('Users', Icons.people_outline), UsersTab()),
    _TabEntry(_TabSpec('Trades', Icons.show_chart), TradesTab()),
    _TabEntry(_TabSpec('Audit', Icons.history), AuditTab()),
  ];

  List<_TabEntry> _computeVisible() =>
      _allTabs.where((t) => !t.massiveOnly || _massiveEnabled).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _visible = _computeVisible();
    _tabs = TabController(length: _visible.length, vsync: this);
    // Bi-directional sync: when the user swipes/taps the bar, push the new
    // index into the provider so other widgets (e.g. Status cards) read the
    // current tab. When the provider mutates (e.g. a card tap calls notifier.state =),
    // the build() listener animates the controller. The `indexIsChanging`
    // guard prevents the two from fighting each other mid-animation.
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final cur = ref.read(adminTabIndexProvider);
      if (cur != _tabs.index) {
        ref.read(adminTabIndexProvider.notifier).state = _tabs.index;
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Rebuilds the tab list/controller when the massiveEnabled flag changes
  /// (only happens on a backend redeploy, but handled live in case the
  /// admin has the dashboard open when it flips). Preserves the current
  /// tab selection where possible.
  void _syncMassiveEnabled(bool enabled) {
    if (enabled == _massiveEnabled) return;
    final currentLabel = _visible[_tabs.index.clamp(0, _visible.length - 1)].spec.label;
    setState(() {
      _massiveEnabled = enabled;
      _visible = _computeVisible();
      final newIndex = _visible.indexWhere((t) => t.spec.label == currentLabel);
      _tabs.dispose();
      _tabs = TabController(
        length: _visible.length,
        vsync: this,
        initialIndex: newIndex >= 0 ? newIndex : 0,
      );
      _tabs.addListener(() {
        if (_tabs.indexIsChanging) return;
        final cur = ref.read(adminTabIndexProvider);
        if (cur != _tabs.index) {
          ref.read(adminTabIndexProvider.notifier).state = _tabs.index;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ref.watch(isAdminProvider);
    // Listen for jump-to-tab requests from anywhere in the tree.
    ref.listen<int>(adminTabIndexProvider, (prev, next) {
      if (next < 0 || next >= _visible.length) return;
      if (_tabs.index != next) {
        _tabs.animateTo(next);
      }
    });
    ref.listen(systemStatusStreamProvider, (prev, next) {
      final enabled = next.valueOrNull?.massiveEnabled;
      if (enabled != null) _syncMassiveEnabled(enabled);
    });
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        elevation: 0,
        title: const Text('Admin',
            style: TextStyle(letterSpacing: 0.8, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.home),
        ),
      ),
      body: SafeArea(
        child: !isAdmin
            ? const EmptyState(
                icon: Icons.lock_outline,
                title: 'Admin only',
                message: 'This dashboard is restricted to admin accounts.',
              )
            : Column(
                children: <Widget>[
                  _TabBarStrip(
                    controller: _tabs,
                    specs: [for (final t in _visible) t.spec],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [for (final t in _visible) t.widget],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _TabBarStrip extends StatelessWidget {
  const _TabBarStrip({required this.controller, required this.specs});
  final TabController controller;
  final List<_TabSpec> specs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.steel),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
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
            fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        unselectedLabelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6),
        tabs: <Widget>[
          for (final s in specs)
            Tab(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(s.icon, size: 14),
                  const SizedBox(width: 6),
                  Text(s.label),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
