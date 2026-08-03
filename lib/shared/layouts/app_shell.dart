import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_state_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';

/// Adaptive nav scaffold for the customer experience.
///
/// On phones (< 720pt wide), uses the iOS-style bottom NavigationBar (4
/// tabs: Home / Scanner / Chat / Profile) and floats the Admin FAB when
/// applicable. The Hot Trades tab was removed August 2026 — Day/Swing/LEAPS
/// channels (now TradingView-sourced) all live on the Scanner tab instead.
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
    final int chatUnread = ref.watch(chatTotalUnreadProvider);
    // Admin destination is appended only when isAdmin is true, so the rail
    // ordering stays stable for non-admins.
    final List<NavigationRailDestination> destinations =
        <NavigationRailDestination>[
      for (final _NavDestination d in _customerTabs)
        NavigationRailDestination(
          icon: _maybeBadge(
            child: Icon(d.icon),
            count: d.path == RoutePaths.chat ? chatUnread : 0,
          ),
          selectedIcon: _maybeBadge(
            child: Icon(d.activeIcon, color: AppColors.gold),
            count: d.path == RoutePaths.chat ? chatUnread : 0,
          ),
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
                HapticFeedback.selectionClick();
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
      // extendBody intentionally false: when true, scrollable children
      // had their final ~114px (nav bar 80 + iOS home indicator 34) hidden
      // behind the NavigationBar because typical screens only pad bottom 24.
      // With extendBody: false the Scaffold reserves the nav bar height
      // for itself, so every screen renders its full content above the
      // chrome with no per-screen padding hack.
      extendBody: false,
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
            HapticFeedback.selectionClick();
            context.go(_customerTabs[i].path);
          },
          destinations: <NavigationDestination>[
            for (final _NavDestination d in _customerTabs)
              NavigationDestination(
                icon: _maybeBadge(
                  child: Icon(d.icon),
                  count: d.path == RoutePaths.chat
                      ? ref.watch(chatTotalUnreadProvider)
                      : 0,
                ),
                selectedIcon: _maybeBadge(
                  child: Icon(d.activeIcon, color: AppColors.gold),
                  count: d.path == RoutePaths.chat
                      ? ref.watch(chatTotalUnreadProvider)
                      : 0,
                ),
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

/// Wrap a nav icon with Flutter's Badge widget when `count` > 0. Returns
/// the child unchanged otherwise. Caps display at "99+" so the badge
/// stays readable. Used by the chat-tab unread rollup.
Widget _maybeBadge({required Widget child, required int count}) {
  if (count <= 0) return child;
  return Badge(
    label: Text(count >= 99 ? '99+' : '$count'),
    backgroundColor: AppColors.gold,
    textColor: AppColors.obsidian,
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
    child: child,
  );
}
