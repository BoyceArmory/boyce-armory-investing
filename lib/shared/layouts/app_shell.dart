import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_state_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';

/// Bottom-nav scaffold for the customer experience. The router populates
/// `child` with the active tab's screen.
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
