import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_container.dart';

/// 3-column quick-action grid (5 tiles: Scanner, Premarket, Chat, Learn,
/// News). Premarket joined the row in May 2026 so the morning watchlist is
/// one tap from home. Premarket has no shipped artwork yet, so its tile
/// falls back to an icon + label until the PNG is added to
/// assets/buttons/premarket_button.png. The Hot Trades tile was removed
/// August 2026 along with the dedicated Hot Trades tab — Scanner covers
/// Day/Swing/LEAPS channels directly now.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_Action> actions = <_Action>[
      _Action(
        asset: AssetPaths.btnScanner,
        path: RoutePaths.scanner,
        fallbackLabel: 'Scanner',
        fallbackIcon: Icons.radar,
      ),
      _Action(
        asset: AssetPaths.btnPremarket,
        path: RoutePaths.premarket,
        fallbackLabel: 'Premarket',
        fallbackIcon: Icons.wb_twilight,
      ),
      _Action(
        asset: AssetPaths.btnChat,
        path: RoutePaths.chat,
        fallbackLabel: 'Chat',
        fallbackIcon: Icons.forum_outlined,
      ),
      _Action(
        asset: AssetPaths.btnLearn,
        path: RoutePaths.lessons,
        fallbackLabel: 'Learn',
        fallbackIcon: Icons.school_outlined,
      ),
      _Action(
        asset: AssetPaths.btnNews,
        path: RoutePaths.news,
        fallbackLabel: 'News',
        fallbackIcon: Icons.article_outlined,
      ),
    ];
    // 5 tiles: phone gets a 3-then-2 grid. iPad gets one horizontal row of
    // all 5 buttons.
    final int cols = isWideScreen(context) ? 5 : 3;
    return GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: <Widget>[
        for (final _Action a in actions) _ActionTile(action: a),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        splashColor: AppColors.gold.withValues(alpha: 0.10),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        onTap: () {
          HapticFeedback.lightImpact();
          context.go(action.path);
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: AppColors.graphite,
            border: Border.all(color: AppColors.steel),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Image.asset(
              action.asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FallbackTile(
                label: action.fallbackLabel,
                icon: action.fallbackIcon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rendered for any quick-action whose PNG asset is missing. Keeps the grid
/// usable while final art is being commissioned (used by Premarket today).
class _FallbackTile extends StatelessWidget {
  const _FallbackTile({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.graphite),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.gold, size: 28),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.asset,
    required this.path,
    required this.fallbackLabel,
    required this.fallbackIcon,
  });
  final String asset;
  final String path;
  final String fallbackLabel;
  final IconData fallbackIcon;
}
