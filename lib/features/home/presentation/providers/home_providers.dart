import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../data/home_overview_model.dart';
import '../../data/home_repository.dart';

final Provider<HomeRepository> homeRepositoryProvider = Provider<HomeRepository>(
  (Ref ref) => HomeRepository(apiClient: ref.watch(apiClientProvider)),
);

/// IV-rank snapshot for SPY/QQQ/IWM. Backend caches 5 min so a slow
/// scrolling user doesn't hammer the endpoint; we refetch on home pull.
final FutureProvider<IvRankSummary> ivRankSummaryProvider =
    FutureProvider<IvRankSummary>((Ref ref) {
  return ref.watch(homeRepositoryProvider).fetchIvRankSummary();
});

/// Auto-refreshing market overview — 30s tick during market hours.
final StreamProvider<HomeOverview> homeOverviewStreamProvider =
    StreamProvider<HomeOverview>((Ref ref) {
  final repo = ref.watch(homeRepositoryProvider);
  // ignore: close_sinks
  final ctrl = StreamController<HomeOverview>();

  Future<void> tick() async {
    try {
      final v = await repo.fetchOverview();
      if (!ctrl.isClosed) ctrl.add(v);
    } catch (e, st) {
      if (!ctrl.isClosed) ctrl.addError(e, st);
    }
  }

  tick();
  final t = Timer.periodic(const Duration(seconds: 30), (_) => tick());
  ref.onDispose(() {
    t.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});
