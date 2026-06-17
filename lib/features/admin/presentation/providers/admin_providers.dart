import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../data/admin_repository.dart';
import '../../data/system_status_model.dart';

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) {
  return AdminRepository(apiClient: ref.watch(apiClientProvider));
});

/// Active tab index for the admin dashboard. Lets any nested widget jump to
/// another tab without prop-drilling a callback through every parent. The
/// dashboard listens to this and animates its TabController whenever the
/// value changes; cards in the Status tab write to it on tap.
final StateProvider<int> adminTabIndexProvider =
    StateProvider<int>((Ref _) => 0);

/// Auto-refreshing system status (30s tick). Used by the Status tab.
final StreamProvider<SystemStatus> systemStatusStreamProvider =
    StreamProvider<SystemStatus>((Ref ref) {
  final AdminRepository repo = ref.watch(adminRepositoryProvider);
  // ignore: close_sinks
  final ctrl = StreamController<SystemStatus>();

  Future<void> tick() async {
    try {
      final s = await repo.fetchSystemStatus();
      if (!ctrl.isClosed) ctrl.add(s);
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

/// Scanner runs feed (auto-refresh every 60s).
final StreamProvider<List<Map<String, dynamic>>> scannerRunsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((Ref ref) {
  final repo = ref.watch(adminRepositoryProvider);
  // ignore: close_sinks
  final ctrl = StreamController<List<Map<String, dynamic>>>();
  Future<void> tick() async {
    try {
      final runs = await repo.listScannerRuns(limit: 50);
      if (!ctrl.isClosed) ctrl.add(runs);
    } catch (e, st) {
      if (!ctrl.isClosed) ctrl.addError(e, st);
    }
  }
  tick();
  final t = Timer.periodic(const Duration(seconds: 60), (_) => tick());
  ref.onDispose(() {
    t.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});

/// One-shot fetches (admin tabs handle their own refresh via invalidate()).
final FutureProvider<List<Map<String, dynamic>>> scannerAlertsForAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listScannerAlerts(includeAdmin: true, limit: 100);
});

final FutureProvider<List<Map<String, dynamic>>> tradeAlertsForAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listTradeAlerts(limit: 50);
});

final FutureProvider<List<Map<String, dynamic>>> adminUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listUsers(limit: 200);
});

/// Recent admin events (new signups, support tickets, etc.) for the
/// Recent Activity strip on the Users tab. One-shot fetch; the tab
/// invalidates on focus + pull-to-refresh.
final FutureProvider<List<Map<String, dynamic>>> adminEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listAdminEvents(limit: 50);
});

/// Count of unread admin events across all kinds. Drives the small badge
/// shown next to "Recent Activity" and (later) the Users tab indicator.
/// Derived from adminEventsProvider so a single network call backs both.
final Provider<int> adminEventsUnreadCountProvider = Provider<int>((Ref ref) {
  final async = ref.watch(adminEventsProvider);
  return async.maybeWhen(
    data: (events) =>
        events.where((e) => (e['read'] as bool? ?? false) == false).length,
    orElse: () => 0,
  );
});

final FutureProvider<List<Map<String, dynamic>>> activeTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listActiveTrades(limit: 50);
});

final FutureProvider<List<Map<String, dynamic>>> closedTradesProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listClosedTrades(limit: 50);
});

final FutureProvider<List<Map<String, dynamic>>> auditLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).listAuditLogs(limit: 100);
});

/// Backtest health summary — refreshes when the user pulls down on the Status
/// tab (invalidated alongside systemStatusStreamProvider). Cheap call, no
/// auto-dispose so the Status tab can re-show it instantly on tab switch.
final FutureProvider<Map<String, dynamic>> backtestHealthProvider =
    FutureProvider<Map<String, dynamic>>((Ref ref) {
  return ref.watch(adminRepositoryProvider).fetchBacktestHealth();
});
