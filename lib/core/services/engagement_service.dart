import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_providers.dart';
import 'api_client.dart';

/// Thin wrapper around the per-user engagement endpoints. Used by alert
/// cards (took/watching/pass) and the scanner filter chip (watchlist).
class EngagementService {
  EngagementService(this._api);
  final ApiClient _api;

  // ---- Alert actions ----

  Future<String?> getAction(String alertId) async {
    try {
      final Map<String, dynamic> r =
          await _api.getJson('/api/users/me/alerts/$alertId/action');
      return r['action'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setAction(String alertId, String action) async {
    try {
      await _api.postJson(
        '/api/users/me/alerts/$alertId/action',
        <String, dynamic>{'action': action},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Watchlist ----

  Future<List<String>> getWatchlist() async {
    try {
      final Map<String, dynamic> r =
          await _api.getJson('/api/users/me/watchlist');
      final List<dynamic> raw =
          (r['watchlist'] as List<dynamic>?) ?? <dynamic>[];
      return raw.whereType<String>().toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> addToWatchlist(String symbol) async {
    try {
      final Map<String, dynamic> r = await _api.postJson(
        '/api/users/me/watchlist',
        <String, dynamic>{'symbol': symbol},
      );
      final List<dynamic> raw =
          (r['watchlist'] as List<dynamic>?) ?? <dynamic>[];
      return raw.whereType<String>().toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<List<String>> removeFromWatchlist(String symbol) async {
    try {
      final Map<String, dynamic> r =
          await _api.deleteJson('/api/users/me/watchlist/$symbol');
      final List<dynamic> raw =
          (r['watchlist'] as List<dynamic>?) ?? <dynamic>[];
      return raw.whereType<String>().toList();
    } catch (_) {
      return <String>[];
    }
  }
}

final Provider<EngagementService> engagementServiceProvider =
    Provider<EngagementService>((Ref ref) {
  return EngagementService(ref.watch(apiClientProvider));
});

/// Cached watchlist as a state notifier so multiple UI surfaces can stay in
/// sync after adds/removes without round-tripping the network each time.
class WatchlistController extends StateNotifier<Set<String>> {
  WatchlistController(this._service) : super(<String>{}) {
    _bootstrap();
  }
  final EngagementService _service;

  Future<void> _bootstrap() async {
    final List<String> initial = await _service.getWatchlist();
    state = initial.toSet();
  }

  Future<void> add(String symbol) async {
    final String upper = symbol.toUpperCase();
    if (state.contains(upper)) return;
    state = <String>{...state, upper};
    final List<String> server = await _service.addToWatchlist(upper);
    if (server.isNotEmpty) state = server.toSet();
  }

  Future<void> remove(String symbol) async {
    final String upper = symbol.toUpperCase();
    if (!state.contains(upper)) return;
    state = state.where((String s) => s != upper).toSet();
    final List<String> server = await _service.removeFromWatchlist(upper);
    if (server.isNotEmpty) state = server.toSet();
  }

  bool contains(String symbol) => state.contains(symbol.toUpperCase());

  Future<void> refresh() async {
    final List<String> server = await _service.getWatchlist();
    state = server.toSet();
  }
}

final StateNotifierProvider<WatchlistController, Set<String>>
    watchlistProvider =
    StateNotifierProvider<WatchlistController, Set<String>>((Ref ref) {
  return WatchlistController(ref.watch(engagementServiceProvider));
});
