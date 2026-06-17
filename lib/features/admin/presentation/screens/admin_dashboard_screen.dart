import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/admin_providers.dart';
import '../widgets/alerts_tab.dart';
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
///   Status   — what's running (auto-refresh 30s).
///   Scanner  — manual trigger, run history, kill switches.
///   Alerts   — scanner + trade alert management, promote to Hot, compose.
///   Users    — list + role/tier/disabled controls.
///   Trades   — active (with close) + closed.
///   Audit    — admin_logs feed.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const List<_TabSpec> _specs = <_TabSpec>[
    _TabSpec('Status', Icons.monitor_heart_outlined),
    _TabSpec('Scanner', Icons.radar),
    _TabSpec('Alerts', Icons.campaign_outlined),
    _TabSpec('Jobs', Icons.flash_on),
    _TabSpec('Push', Icons.notifications_active_outlined),
    _TabSpec('Backtest', Icons.analytics_outlined),
    _TabSpec('Detectors', Icons.tune),
    _TabSpec('Cooldowns', Icons.timer_outlined),
    _TabSpec('Learning', Icons.school_outlined),
    _TabSpec('Users', Icons.people_outline),
    _TabSpec('Trades', Icons.show_chart),
    _TabSpec('Audit', Icons.history),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _specs.length, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ref.watch(isAdminProvider);
    // Listen for jump-to-tab requests from anywhere in the tree.
    ref.listen<int>(adminTabIndexProvider, (prev, next) {
      if (next < 0 || next >= _specs.length) return;
      if (_tabs.index != next) {
        _tabs.animateTo(next);
      }
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
                  _TabBarStrip(controller: _tabs, specs: _specs),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: const <Widget>[
                        StatusTab(),
                        ScannerOpsTab(),
                        AlertsTab(),
                        JobsTab(),
                        PushTab(),
                        BacktestTab(),
                        DetectorsTab(),
                        CooldownsTab(),
                        LearningTab(),
                        UsersTab(),
                        TradesTab(),
                        AuditTab(),
                      ],
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
