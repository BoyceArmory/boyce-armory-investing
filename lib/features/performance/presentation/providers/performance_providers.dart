import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../data/performance_models.dart';
import '../../data/performance_repository.dart';

/// Single instance of the repository, wired with the shared ApiClient.
final Provider<PerformanceRepository> performanceRepositoryProvider =
    Provider<PerformanceRepository>((Ref ref) {
  return PerformanceRepository(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// All-time global stats. FutureProvider — refreshes on pull-to-refresh.
final FutureProvider<PerformanceStats> globalPerformanceStatsProvider =
    FutureProvider<PerformanceStats>((Ref ref) {
  return ref.watch(performanceRepositoryProvider).fetchGlobalStats();
});

/// Live stream of recent closed trades.
final StreamProvider<List<ClosedTrade>> recentClosedTradesProvider =
    StreamProvider<List<ClosedTrade>>((Ref ref) {
  return ref
      .watch(performanceRepositoryProvider)
      .streamRecentClosedTrades(limit: 25);
});
