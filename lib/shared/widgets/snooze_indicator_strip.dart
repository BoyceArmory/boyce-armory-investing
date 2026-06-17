import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/data/snooze_service.dart';

/// Reusable gold strip that surfaces the user's global snooze state from
/// anywhere in the app. Watches [activeSnoozeProvider]; renders nothing
/// when not snoozed. Tapping routes to Settings so the user can extend
/// or cancel without hunting.
///
/// Use the [compact] variant on dense screens (Hot Trades, Scanner) —
/// it drops the chevron, shrinks padding, and uses one short line so the
/// strip doesn't dominate the header area. The home screen uses the full
/// variant ([compact]:false) so the message stands out as a meaningful
/// status, not a tab annotation.
class SnoozeIndicatorStrip extends ConsumerWidget {
  const SnoozeIndicatorStrip({super.key, this.compact = false});

  /// Compact mode = single-line, no chevron, smaller paddings.
  final bool compact;

  String _remaining(DateTime until) {
    final d = until.difference(DateTime.now());
    if (d.isNegative) return 'expired';
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h ${m}m left';
    }
    return '${d.inMinutes}m left';
  }

  String _untilLabel(DateTime until) {
    final local = until.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    if (sameDay) return 'until $h:$m';
    return 'until ${local.month}/${local.day} $h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final until = ref
        .watch(activeSnoozeProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
    if (until == null) return const SizedBox.shrink();

    final vPad = compact ? 7.0 : 10.0;
    final hPad = compact ? 12.0 : 14.0;
    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 10 : 14),
      onTap: () => context.go(RoutePaths.settings),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.bedtime,
                color: AppColors.gold, size: compact ? 16 : 18),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: compact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  children: <InlineSpan>[
                    const TextSpan(
                      text: 'Snoozed',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(text: ' ${_untilLabel(until)} · '),
                    TextSpan(
                      text: _remaining(until),
                      style: const TextStyle(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
            if (!compact)
              const Icon(Icons.chevron_right,
                  color: AppColors.gold, size: 18),
          ],
        ),
      ),
    );
  }
}
