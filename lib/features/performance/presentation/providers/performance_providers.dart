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

/// Live stream of recent closed trades — every entry in `closed_trades`,
/// regardless of origin. Used as the source of truth that downstream
/// filtered providers (user trades vs shadow trades) read from.
final StreamProvider<List<ClosedTrade>> recentClosedTradesProvider =
    StreamProvider<List<ClosedTrade>>((Ref ref) {
  return ref
      .watch(performanceRepositoryProvider)
      .streamRecentClosedTrades(limit: 50);
});

/// User-taken trades only (real positions — admin closes, "I took this
/// trade" flow, bulk-imported Webull history). Powers the "My Trades"
/// tab. Uses a dedicated repository stream that over-fetches and filters
/// at the Flutter layer, because Firestore `!=` queries would skip legacy
/// docs lacking a `source` field.
final StreamProvider<List<ClosedTrade>> userClosedTradesProvider =
    StreamProvider<List<ClosedTrade>>((Ref ref) {
  return ref
      .watch(performanceRepositoryProvider)
      .streamUserClosedTrades(limit: 100);
});

/// Scanner-tracked simulated outcomes — the auto-opened shadow trade on
/// every A/A+ alert. Powers the "Scanner Track Record" tab. Indexed
/// on `source == "shadow"` so the query is cheap and no over-fetch is
/// needed.
final StreamProvider<List<ClosedTrade>> shadowClosedTradesProvider =
    StreamProvider<List<ClosedTrade>>((Ref ref) {
  return ref
      .watch(performanceRepositoryProvider)
      .streamShadowClosedTrades(limit: 100);
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
