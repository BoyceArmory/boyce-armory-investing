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

/// Premarket watchlist — populated by the backend premarket-scan job
/// at 9:25 AM ET each weekday. Empty outside premarket window until the
/// next morning's run, which is when the EmptyAlertCard explains the
/// scanner schedule.
final StreamProvider<List<TradeAlert>> premarketAlertsProvider =
    StreamProvider<List<TradeAlert>>(
  (Ref ref) => ref.watch(alertsRepositoryProvider).streamPremarket(),
);

/// Single alert by id, used by the detail screen.
final StreamProviderFamily<TradeAlert?, String> alertByIdProvider =
    StreamProvider.family<TradeAlert?, String>(
  (Ref ref, String id) =>
      ref.watch(alertsRepositoryProvider).streamById(id),
);
