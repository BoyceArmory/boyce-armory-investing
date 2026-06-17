import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/enums.dart';
import '../../core/models/trade_alert_model.dart';
import '../../core/routing/route_paths.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/engagement_service.dart';
import '../../core/theme/app_colors.dart';

/// Power-user action sheet that opens on a Hot Trade / Scanner card
/// long-press. Mirrors the iOS app pattern of "tap = primary action,
/// long-press = quick menu" so we don't clutter the card with secondary
/// affordances. All actions are reachable via taps elsewhere too — this
/// sheet just batches them for speed.
///
/// Actions:
///   - Add to / remove from watchlist (mirrors the star)
///   - Open chart for the ticker
///   - Copy entry / target / stop to clipboard
///   - Open the alert detail (tap-equivalent)
class AlertActionsSheet extends ConsumerWidget {
  const AlertActionsSheet({super.key, required this.alert});
  final TradeAlert alert;

  static Future<void> show(BuildContext context, TradeAlert alert) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext c) => AlertActionsSheet(alert: alert),
    );
  }

  String _planLine() {
    final entry = alert.entry.toStringAsFixed(2);
    final target = alert.target?.toStringAsFixed(2) ?? '—';
    final stop = alert.stop?.toStringAsFixed(2) ?? '—';
    return '${alert.symbol} ${alert.direction.wire} · entry $entry · target $target · stop $stop';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inWatchlist =
        ref.watch(watchlistProvider).contains(alert.symbol.toUpperCase());
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header: symbol + plan in one glance so the user knows
            // which card they long-pressed.
            Text(
              '${alert.symbol} · ${alert.direction.wire}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _planLine(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _Action(
              icon: inWatchlist ? Icons.star : Icons.star_border,
              label: inWatchlist
                  ? 'Remove ${alert.symbol} from watchlist'
                  : 'Add ${alert.symbol} to watchlist',
              tone:
                  inWatchlist ? AppColors.textSecondary : AppColors.gold,
              onTap: () {
                Navigator.pop(context);
                final ctl = ref.read(watchlistProvider.notifier);
                if (inWatchlist) {
                  ctl.remove(alert.symbol);
                  AnalyticsService.watchlistRemoved(alert.symbol);
                } else {
                  ctl.add(alert.symbol);
                  AnalyticsService.watchlistAdded(alert.symbol);
                }
              },
            ),
            const _Divider(),
            _Action(
              icon: Icons.candlestick_chart_outlined,
              label: 'Open chart for ${alert.symbol}',
              tone: AppColors.gold,
              onTap: () {
                Navigator.pop(context);
                context.go(RoutePaths.chartFor(alert.symbol));
              },
            ),
            const _Divider(),
            _Action(
              icon: Icons.copy_all_outlined,
              label: 'Copy entry / target / stop',
              tone: AppColors.gold,
              onTap: () {
                final entry = alert.entry.toStringAsFixed(2);
                final target = alert.target?.toStringAsFixed(2) ?? '—';
                final stop = alert.stop?.toStringAsFixed(2) ?? '—';
                Clipboard.setData(ClipboardData(
                  text:
                      '${alert.symbol} ${alert.direction.wire}\nEntry: $entry\nTarget: $target\nStop: $stop',
                ));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trade plan copied')),
                );
              },
            ),
            const _Divider(),
            _Action(
              icon: Icons.info_outline,
              label: 'Open alert detail',
              tone: AppColors.gold,
              onTap: () {
                Navigator.pop(context);
                context.go(RoutePaths.alertDetailFor(alert.id));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, color: tone, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tone,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.steel, height: 1);
}
