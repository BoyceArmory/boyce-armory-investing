import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Tap-to-toggle star icon for adding a ticker to the user's watchlist.
/// Sits in the top-right of every alert card. Optimistic UI — state
/// flips immediately, server reconciles in the background.
class WatchlistStar extends ConsumerWidget {
  const WatchlistStar({super.key, required this.symbol});
  final String symbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> watchlist = ref.watch(watchlistProvider);
    final bool inList = watchlist.contains(symbol.toUpperCase());
    return GestureDetector(
      onTap: () {
        final WatchlistController ctl = ref.read(watchlistProvider.notifier);
        if (inList) {
          ctl.remove(symbol);
          AnalyticsService.watchlistRemoved(symbol);
        } else {
          ctl.add(symbol);
          AnalyticsService.watchlistAdded(symbol);
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
