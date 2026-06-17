import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Tap-to-toggle star icon for adding a ticker to the user's watchlist.
/// Sits in the top-right of every alert card. Optimistic UI — state
/// flips immediately, server reconciles in the background.
///
/// On tap a snackbar surfaces the change with an Undo action — gives
/// users a quick recovery path if they tap the wrong card and prevents
/// the silent "did anything happen?" feel of the previous toggle.
class WatchlistStar extends ConsumerWidget {
  const WatchlistStar({super.key, required this.symbol});
  final String symbol;

  void _showFeedback(BuildContext context, String sym, bool added,
      VoidCallback undo) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: added ? AppColors.bullish : AppColors.graphite,
        content: Text(
          added
              ? '$sym added to your watchlist'
              : '$sym removed from your watchlist',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.gold,
          onPressed: undo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> watchlist = ref.watch(watchlistProvider);
    final bool inList = watchlist.contains(symbol.toUpperCase());
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final WatchlistController ctl = ref.read(watchlistProvider.notifier);
        if (inList) {
          ctl.remove(symbol);
          AnalyticsService.watchlistRemoved(symbol);
          _showFeedback(context, symbol, false, () {
            ctl.add(symbol);
            AnalyticsService.watchlistAdded(symbol);
          });
        } else {
          ctl.add(symbol);
          AnalyticsService.watchlistAdded(symbol);
          _showFeedback(context, symbol, true, () {
            ctl.remove(symbol);
            AnalyticsService.watchlistRemoved(symbol);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          inList ? Icons.star : Icons.star_border,
          size: 20,
          color: inList ? AppColors.gold : Colors.white54,
        ),
      ),
    );
  }
}
