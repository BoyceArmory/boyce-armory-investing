import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_state_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';

/// Adaptive nav scaffold for the customer experience.
///
/// On phones (< 720pt wide), uses the iOS-style bottom NavigationBar (5
/// tabs: Home / Hot / Scanner / Chat / Profile) and floats the Admin FAB
/// when applicable.
///
/// On iPad / wide screens, switches to a left-edge NavigationRail with the
/// same destinations + an Admin destination inline when the user is an
/// admin. The body fills the remaining horizontal space — combined with
/// ResponsiveContainer inside each screen, this gives a sidebar +
/// centered-content layout that feels native on tablets.
///
/// Breakpoint: 720pt. iPad mini portrait (~768pt) trips into rail mode;
/// iPhone landscape (~844pt on Pro Max) also gets rail mode, which works
/// fine because landscape iPhone is essentially a small tablet.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const List<_NavDestination> _customerTabs = <_NavDestination>[
    _NavDestination(RoutePaths.home, Icons.home_outlined, Icons.home, 'Home'),
    _NavDestination(RoutePaths.hotTrades, Icons.local_fire_department_outlined,
        Icons.local_fire_department, 'Hot'),
    _NavDestination(RoutePaths.scanner, Icons.radar_outlined, Icons.radar,
        'Scanner'),
    _NavDestination(RoutePaths.chat, Icons.forum_outlined, Icons.forum, 'Chat'),
    _NavDestination(RoutePaths.profile, Icons.person_outline, Icons.person,
        'Profile'),
  ];

  int _indexFor(String location) {
    for (int i = 0; i < _customerTabs.length; i++) {
      if (location.startsWith(_customerTabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final int selected = _indexFor(location);
    final bool isAdmin = ref.watch(isAdminProvider);
    final double w = MediaQuery.sizeOf(context).width;
    final bool useRail = w >= 720;

    if (useRail) {
      return _buildRailScaffold(context, selected, isAdmin);
    }
    return _buildBottomNavScaffold(context, selected, isAdmin);
  }

  // ---- iPad / wide-screen layout: NavigationRail on the left ----------------

  Widget _buildRailScaffold(BuildContext context, int selected, bool isAdmin) {
    // Admin destination is appended only when isAdmin is true, so the rail
    // ordering stays stable for non-admins.
    final List<NavigationRailDestination> destinations =
        <NavigationRailDestination>[
      for (final _NavDestination d in _customerTabs)
        NavigationRailDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.activeIcon, color: AppColors.gold),
          label: Text(d.label),
        ),
      if (isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings, color: AppColors.gold),
          label: Text('Admin'),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            NavigationRail(
              backgroundColor: AppColors.graphite,
              selectedIndex: selected,
              onDestinationSelected: (int i) {
                if (i < _customerTabs.length) {
                  context.go(_customerTabs[i].path);
                } else if (isAdmin) {
                  context.go(RoutePaths.adminDashboard);
                }
              },
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: AppColors.gold),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
              unselectedIconTheme:
                  const IconThemeData(color: AppColors.textSecondary),
              unselectedLabelTextStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              destinations: destinations,
            ),
            const VerticalDivider(
              width: 1,
              color: AppColors.steel,
            ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }

  // ---- Phone layout: bottom NavigationBar + Admin FAB -----------------------

  Widget _buildBottomNavScaffold(
      BuildContext context, int selected, bool isAdmin) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      extendBody: true,
      body: SafeArea(bottom: false, child: widget.child),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go(RoutePaths.adminDashboard),
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.obsidian,
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin'),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.steel),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (int i) {
            context.go(_customerTabs[i].path);
          },
          destinations: <NavigationDestination>[
            for (final _NavDestination d in _customerTabs)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.activeIcon, color: AppColors.gold),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination(this.path, this.icon, this.activeIcon, this.label);
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
