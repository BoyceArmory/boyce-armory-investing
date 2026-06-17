import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/option_contract_model.dart';
import '../providers/api_providers.dart';
import 'api_client.dart';

/// Position sizing math. Mirrors `position-sizing.service.ts` in the
/// backend — same defensive null-checks, same formula. We compute it
/// client-side because the alert cards need to render the suggestion
/// every time they appear and the math is cheap.
///
/// Bedrock rule: never risk more than maxRiskPct of the account on a
/// single trade. For long options the entire premium is at risk, so:
///   maxLossPerContract = mid * 100
///   contracts = floor(riskBudget / maxLossPerContract)
class PositionSizing {
  /// Returns null when any required input is missing or when the user
  /// can't afford even one contract on their stated risk budget.
  static SizingResult? compute({
    required double accountSize,
    required double maxRiskPct,
    required OptionContract contract,
  }) {
    if (!accountSize.isFinite || accountSize <= 0) return null;
    if (!maxRiskPct.isFinite || maxRiskPct <= 0) return null;
    final mid = contract.mid;
    if (mid == null || mid <= 0) return null;
    final maxLossPerContract = mid * 100;
    final riskBudget = accountSize * (maxRiskPct / 100);
    final contracts = (riskBudget / maxLossPerContract).floor();
    if (contracts <= 0) return null;
    final totalCost = contracts * maxLossPerContract;
    return SizingResult(
      contracts: contracts,
      totalCost: _round(totalCost, 2),
      maxLoss: _round(totalCost, 2),
      riskPct: _round((totalCost / accountSize) * 100, 2),
    );
  }
}

class SizingResult {
  const SizingResult({
    required this.contracts,
    required this.totalCost,
    required this.maxLoss,
    required this.riskPct,
  });
  final int contracts;
  final double totalCost;
  final double maxLoss;
  final double riskPct;
}

double _round(double n, int places) {
  final p = math.pow(10, places).toDouble();
  return (n * p).round() / p;
}

/// Persisted sizing preferences.
class SizingPrefs {
  const SizingPrefs({this.accountSize, this.maxRiskPct});
  final double? accountSize;
  final double? maxRiskPct;

  bool get isComplete =>
      accountSize != null && accountSize! > 0 && maxRiskPct != null;

  factory SizingPrefs.fromJson(Map<String, dynamic> j) => SizingPrefs(
        accountSize: (j['accountSize'] as num?)?.toDouble(),
        maxRiskPct: (j['maxRiskPct'] as num?)?.toDouble(),
      );

  SizingPrefs copyWith({double? accountSize, double? maxRiskPct}) =>
      SizingPrefs(
        accountSize: accountSize ?? this.accountSize,
        maxRiskPct: maxRiskPct ?? this.maxRiskPct,
      );
}

/// Thin repository over the /api/users/me/sizing endpoints.
class SizingPrefsService {
  SizingPrefsService(this._api);
  final ApiClient _api;

  Future<SizingPrefs> fetch() async {
    try {
      final j = await _api.getJson('/api/users/me/sizing');
      final p = (j['prefs'] as Map?)?.cast<String, dynamic>() ?? const {};
      return SizingPrefs.fromJson(p);
    } catch (_) {
      return const SizingPrefs();
    }
  }

  Future<bool> update({double? accountSize, double? maxRiskPct}) async {
    try {
      final body = <String, dynamic>{};
      if (accountSize != null) body['accountSize'] = accountSize;
      if (maxRiskPct != null) body['maxRiskPct'] = maxRiskPct;
      await _api.patchJson('/api/users/me/sizing', body: body);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final Provider<SizingPrefsService> sizingPrefsServiceProvider =
    Provider<SizingPrefsService>((Ref ref) {
  return SizingPrefsService(ref.watch(apiClientProvider));
});

/// Cached sizing prefs. Loads once on first read; updates optimistically.
/// Cards read this without round-tripping the network per build.
class SizingPrefsController extends StateNotifier<SizingPrefs> {
  SizingPrefsController(this._service) : super(const SizingPrefs()) {
    _bootstrap();
  }
  final SizingPrefsService _service;

  Future<void> _bootstrap() async {
    final p = await _service.fetch();
    state = p;
  }

  Future<void> setAccountSize(double v) async {
    state = state.copyWith(accountSize: v);
    await _service.update(accountSize: v);
  }

  Future<void> setMaxRiskPct(double v) async {
    state = state.copyWith(maxRiskPct: v);
    await _service.update(maxRiskPct: v);
  }

  Future<void> refresh() async {
    state = await _service.fetch();
  }
}

final StateNotifierProvider<SizingPrefsController, SizingPrefs>
    sizingPrefsProvider =
    StateNotifierProvider<SizingPrefsController, SizingPrefs>((Ref ref) {
  return SizingPrefsController(ref.watch(sizingPrefsServiceProvider));
});
