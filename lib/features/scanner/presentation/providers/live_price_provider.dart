import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';

/// Live underlying price for a single symbol.
///
/// Unused since Scalp mode (0DTE) was removed in July 2026 — the only
/// caller was the scalp meta strip. Left in place (no remaining callers,
/// harmless) rather than deleted.
///
/// Polling cadence: 15 seconds. autoDispose so the timer is torn down the
/// second the card scrolls offscreen.
///
/// Endpoint: GET /api/market/quote/{symbol} -> { price, ... }
///
/// Returns null until the first fetch resolves, and on every failure so
/// the UI can fall back to the snapshot price on the alert payload.
final AutoDisposeStreamProviderFamily<double?, String> livePriceProvider =
    StreamProvider.autoDispose.family<double?, String>((Ref ref, String symbol) {
  final apiClient = ref.watch(apiClientProvider);
  final controller = StreamController<double?>();

  Future<void> tick() async {
    try {
      final json = await apiClient.getJson('/market/quote/$symbol');
      final raw = json['price'];
      final double? price = raw is num ? raw.toDouble() : null;
      if (!controller.isClosed) controller.add(price);
    } catch (_) {
      if (!controller.isClosed) controller.add(null);
    }
  }

  // Fire immediately, then every 15 seconds. The first emission gives the
  // card a fresh price within ~half a second of the user opening the
  // screen; the timer keeps it fresh while they look at it.
  tick();
  final timer = Timer.periodic(const Duration(seconds: 15), (_) => tick());

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
