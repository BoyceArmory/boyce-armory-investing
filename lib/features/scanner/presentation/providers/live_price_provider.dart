import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';

/// Live underlying price for a single symbol. Used by scalp cards so the
/// 10-min-TTL card shows a live price instead of the stale snapshot taken
/// at fire time.
///
/// Polling cadence: 15 seconds. June 2026 bump (from 30s) — Polygon
/// Advanced has no rate limit and scalps live and die on price moves
/// inside any given minute. 15s is the right granularity for a 10-min
/// TTL position. autoDispose so the timer is torn down the second the
/// card scrolls offscreen.
///
/// Endpoint: GET /api/market/quote/{symbol} → { price, ... }
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
    timer