import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_paths.dart';
import '../../core/services/engagement_service.dart';
import '../../core/theme/app_colors.dart';

/// Bottom sheet that shows every ticker the user has starred plus actions
/// to remove individual tickers, clear the whole list, or jump straight
/// to a ticker's chart.
///
/// Used from two surfaces today:
///   - Hot Trades "Watchlist" filter chip — tap to manage when the chip
///     would otherwise be empty.
///   - Settings → "My watchlist" tile.
///
/// Optimistic UI: removes flip state immediately on tap; the
/// WatchlistController reconciles with the server in the background.
class WatchlistManagerSheet extends ConsumerWidget {
  const WatchlistManagerSheet({super.key});

  /// Helper so callers don't have to remember the shape parameters.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.graphite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const WatchlistManagerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbols = ref.watch(watchlistProvider);
    final sorted = symbols.toList()..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.steel,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.star, color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'My Watchlist',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (sorted.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      final confirmed = await _confirmClearAll(context);
                      if (!confirmed) return;
                      final ctl = ref.read(watchlistProvider.notifier);
                      // Clear sequentially through the controller so the
                      // server gets remove calls per ticker. The state
                      // notifier coalesces UI rebuilds.
                      for (final s in sorted) {
                        await ctl.remove(s);
                      }
                    },
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        color: AppColors.bearish,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${sorted.length} ticker${sorted.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.steel, height: 1),
          Expanded(
            child: sorted.isEmpty
                ? const _EmptyWatchlist()
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _WatchlistRow(
                      symbol: sorted[i],
                      onRemove: () => ref
                          .read(watchlistProvider.notifier)
                          .remove(sorted[i]),
                      onOpenChart: () {
                        Navigator.of(context).maybePop();
                        context.go(RoutePaths.chartFor(sorted[i]));
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmClearAll(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: const Text(
          'Clear watchlist?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This removes every ticker from your watchlist. You can re-add '
          'them by tapping the star on any alert card.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all',
                style: TextStyle(
                    color: AppColors.bearish,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _WatchlistRow extends StatelessWidget {
  const _WatchlistRow({
    required this.symbol,
    required this.onRemove,
    required this.onOpenChart,
  });
  final String symbol;
  final VoidCallback onRemove;
  final VoidCallback onOpenChart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.carbon,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onOpenChart,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.steel),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: AppColors.gold, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  symbol,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Icon(Icons.show_chart,
                  color: AppColors.textTertiary, size: 16),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remove from watchlist',
                onPressed: onRemove,
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 36, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_outline,
              color: AppColors.textTertiary, size: 40),
          SizedBox(height: 10),
          Text(
            'No watched tickers yet',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Tap the star on any alert card to save its ticker here. '
            'You can filter Hot Trades to watched tickers only with the '
            '"Watchlist" chip.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4),
          ),
        ],
      ),
    );
  }
}
