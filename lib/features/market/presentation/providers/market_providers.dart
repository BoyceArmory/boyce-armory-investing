import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/market_context_model.dart';
import '../../../../core/providers/api_providers.dart';
import '../../data/market_repository.dart';

final Provider<MarketRepository> marketRepositoryProvider =
    Provider<MarketRepository>(
  (Ref ref) => MarketRepository(apiClient: ref.watch(apiClientProvider)),
);

/// One-shot fetch of SPY/QQQ/DIA/VIX. Refreshes when invalidated.
final FutureProvider<MarketContext> marketContextProvider =
    FutureProvider<MarketContext>((Ref ref) {
  return ref.watch(marketRepositoryProvider).fetchContext();
});
