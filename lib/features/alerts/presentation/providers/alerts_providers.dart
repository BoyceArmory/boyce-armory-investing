import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/trade_alert_model.dart';
import '../../../../core/providers/service_providers.dart';
import '../../data/alerts_repository.dart';

final Provider<AlertsRepository> alertsRepositoryProvider =
    Provider<AlertsRepository>((Ref ref) {
  return AlertsRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

/// Recent public trade alerts.
final StreamProvider<List<TradeAlert>> recentAlertsProvider =
    StreamProvider<List<TradeAlert>>(
  (Ref ref) => ref.watch(alertsRepositoryProvider).streamRecent(),
);

/// Hot trades only.
final StreamProvider<List<TradeAlert>> hotAlertsProvider =
    StreamProvider<List<TradeAlert>>(
  (Ref ref) => ref.watch(alertsRepositoryProvider).streamHot(),
);

/// Single alert by id, used by the detail screen.
final StreamProviderFamily<TradeAlert?, String> alertByIdProvider =
    StreamProvider.family<TradeAlert?, String>(
  (Ref ref, String id) =>
      ref.watch(alertsRepositoryProvider).streamById(id),
);
