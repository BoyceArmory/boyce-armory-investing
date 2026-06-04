import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../data/performance_models.dart';
import '../../data/performance_repository.dart';
import '../../data/shadow_models.dart';
import '../../data/shadow_repository.dart';

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

// ---- Shadow-trading providers (scanner auto-tracked simulated trades) ----

final Provider<ShadowRepository> shadowRepositoryProvider =
    Provider<ShadowRepository>((Ref ref) {
  return ShadowRepository(apiClient: ref.watch(apiClientProvider));
});

/// Aggregate shadow-trading stats over a configurable window.
/// Defaults to 30 days — matches how customers think about track records.
final shadowStatsProvider =
    FutureProvider.family<ShadowStats, int>((Ref ref, int windowDays) {
  return ref
      .watch(shadowRepositoryProvider)
      .fetchStats(windowDays: windowDays);
});

/// Recent closed shadow trades — for the "Recent Tracks" feed.
final FutureProvider<List<ShadowTradeRecord>> shadowRecentProvider =
    FutureProvider<List<ShadowTradeRecord>>((Ref ref) {
  return ref.watch(shadowRepositoryProvider).fetchRecent(limit: 50);
});

/// Currently-open shadow positions — for the "Live Tracking" panel.
final FutureProvider<List<ShadowTradeRecord>> shadowOpenProvider =
    FutureProvider<List<ShadowTradeRecord>>((Ref ref) {
  return ref.watch(shadowRepositoryProvider).fetchOpen();
});
