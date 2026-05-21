import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';

/// 2x2 grid of large, image-driven quick-action buttons.
///
/// Each tile uses a full button artwork asset (the design ships pre-styled
/// buttons rather than icon+label, so this widget just renders the image
/// inside a tappable card with subtle press feedback).
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_Action> actions = const <_Action>[
      _Action(asset: AssetPaths.btnHotTrades, path: RoutePaths.hotTrades),
      _Action(asset: AssetPaths.btnScanner, path: RoutePaths.scanner),
      _Action(asset: AssetPaths.btnChat, path: RoutePaths.chat),
      _Action(asset: AssetPaths.btnLearn, path: RoutePaths.lessons),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
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
    final BorderRadius radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        splashColor: AppColors.gold.withValues(alpha: 0.10),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        onTap: () => context.go(action.path),
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
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.graphite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action {
  const _Action({required this.asset, required this.path});
  final String asset;
  final String path;
}
