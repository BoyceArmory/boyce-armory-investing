import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/option_contract_model.dart';
import '../../core/routing/route_paths.dart';
import '../../core/services/position_sizing.dart';
import '../../core/theme/app_colors.dart';

/// Inline chip that shows "X contracts · $Y · Z% risk" for a given option
/// contract using the user's stored sizing prefs.
///
/// Three states:
///   1. No prefs yet → "Set sizing →" CTA that routes to Settings.
///   2. Prefs set + contract priceable → the sized recommendation chip.
///   3. Prefs set but contract can't be sized (no mid, or even 1 ct over
///      risk budget) → "Sizing N/A" muted chip with the reason.
///
/// Designed to fit inline on the expanded sections of HotTradeCard,
/// ScannerAlertCard, and the AlertDetail screen. Tap opens Settings so
/// the user can edit their numbers.
class PositionSizingChip extends ConsumerWidget {
  const PositionSizingChip({super.key, required this.contract});

  final OptionContract? contract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (contract == null) return const SizedBox.shrink();
    final prefs = ref.watch(sizingPrefsProvider);

    if (!prefs.isComplete) {
      return _ChipShell(
        onTap: () => context.go(RoutePaths.settings),
        icon: Icons.tune,
        color: AppColors.textSecondary,
        children: const [
          Text('Set sizing',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4)),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward,
              size: 10, color: AppColors.textSecondary),
        ],
      );
    }

    final result = PositionSizing.compute(
      accountSize: prefs.accountSize!,
      maxRiskPct: prefs.maxRiskPct!,
      contract: contract!,
    );

    if (result == null) {
      return _ChipShell(
        onTap: () => context.go(RoutePaths.settings),
        icon: Icons.info_outline,
        color: AppColors.textTertiary,
        children: const [
          Text('Sizing N/A',
              style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );
    }

    return _ChipShell(
      onTap: () => context.go(RoutePaths.settings),
      icon: Icons.scale,
      color: AppColors.gold,
      children: [
        Text(
          '${result.contracts} ct',
          style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4),
        ),
        const SizedBox(width: 6),
        Text(
          '\$${_fmt(result.totalCost)}',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 6),
        Text(
          '· ${result.riskPct.toStringAsFixed(1)}%',
          style: const TextStyle(
              color: AppColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

String _fmt(double v) {
  if (v >= 1000) {
    return v.toStringAsFixed(0);
  }
  return v.toStringAsFixed(2);
}

class _ChipShell extends StatelessWidget {
  const _ChipShell({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.children,
  });
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            ...children,
          ],
        ),
      ),
    );
  }
}
