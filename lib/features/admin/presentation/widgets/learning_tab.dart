import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/api_providers.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';

/// Admin Learning Insights tab.
///
/// Pulls `/api/admin/learning/insights` and renders the multi-dimensional
/// slice of closed_trades data. Each section answers a tunable question:
///
///   - Score-band calibration → "Does score 90+ actually win more than 80-90?"
///   - Regime expectancy     → "Which regime do detectors win in?"
///   - Session expectancy    → "Which time of day works?"
///   - Catalyst lift         → "Does the +5 news catalyst boost help?"
///   - Flow confirmation lift → "Does cross-API flow agreement predict wins?"
///   - Top/worst detectors   → "Which kinds are pulling weight?"
///
/// Use the window picker to see short-term (7d) trends vs longer (90d) means.
class LearningTab extends ConsumerStatefulWidget {
  const LearningTab({super.key});

  @override
  ConsumerState<LearningTab> createState() => _LearningTabState();
}

class _LearningTabState extends ConsumerState<LearningTab> {
  int _windowDays = 30;
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final ApiClient api = ref.read(apiClientProvider);
    setState(() {
      _future = api.getJson('/api/admin/learning/insights?days=$_windowDays');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              for (final int d in <int>[7, 30, 90])
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _windowDays = d;
                      _refresh();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _windowDays == d
                            ? AppColors.gold
                            : Colors.transparent,
                        border: Border.all(
                          color: _windowDays == d
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          '${d}D',
                          style: TextStyle(
                            color: _windowDays == d
                                ? AppColors.obsidian
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.gold),
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _future,
            builder: (BuildContext c,
                AsyncSnapshot<Map<String, dynamic>?> snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: LoadingIndicator());
              }
              if (snap.hasError) {
                return ErrorState(
                  message: 'Could not load insights',
                  details: '${snap.error}',
                );
              }
              final Map<String, dynamic>? data = snap.data;
              if (data == null || data['totalTrades'] == 0) {
                return const EmptyState(
                  icon: Icons.hourglass_empty,
                  title: 'No closed trades in this window',
                  message:
                      'Shadow trades will accumulate as the scanner fires. Check back tomorrow.',
                );
              }
              return _Body(data: data);
            },
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        _Hero(data: data),
        const SizedBox(height: 16),
        _Section(
          title: 'SCORE-BAND CALIBRATION',
          subtitle:
              'Does a higher score predict a higher win rate? Should be monotonic.',
          rows: _scoreBandRows(data),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'BY REGIME',
          subtitle: 'Bull / bear / chop breakdown.',
          rows: _regimeRows(data),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'BY SESSION',
          subtitle: 'Morning / lunch / afternoon win rates.',
          rows: _sessionRows(data),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'NEWS CATALYST LIFT',
          subtitle: 'Does the +5 catalyst boost help or hurt?',
          rows: _catalystRows(data),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'OPTIONS FLOW CONFIRMATION',
          subtitle:
              'When options flow agrees with signal direction, are outcomes better?',
          rows: _flowRows(data),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'TOP DETECTORS',
          subtitle: 'Most profitable (min 5 trades).',
          rows: _detectorRows(data, top: true),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'WORST DETECTORS',
          subtitle: 'Bleeding the most R-multiple.',
          rows: _detectorRows(data, top: false),
        ),
      ],
    );
  }

  List<_RowSpec> _scoreBandRows(Map<String, dynamic> d) {
    final List<dynamic> bands = (d['scoreBands'] as List<dynamic>?) ?? <dynamic>[];
    return bands.map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return _RowSpec(
        label: (m['band'] as String?) ?? '?',
        right:
            '${_pct(m['winRate'])} • ${(m['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (m['avgRMultiple'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  List<_RowSpec> _regimeRows(Map<String, dynamic> d) {
    final List<dynamic> r = (d['regimes'] as List<dynamic>?) ?? <dynamic>[];
    return r.map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return _RowSpec(
        label: (m['regime'] as String?)?.toUpperCase() ?? '?',
        right:
            '${_pct(m['winRate'])} • ${(m['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (m['avgRMultiple'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  List<_RowSpec> _sessionRows(Map<String, dynamic> d) {
    final List<dynamic> r = (d['sessions'] as List<dynamic>?) ?? <dynamic>[];
    return r.map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return _RowSpec(
        label: (m['session'] as String?)?.toUpperCase() ?? '?',
        right:
            '${_pct(m['winRate'])} • ${(m['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (m['avgRMultiple'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  List<_RowSpec> _catalystRows(Map<String, dynamic> d) {
    final Map<String, dynamic>? c = d['catalyst'] as Map<String, dynamic>?;
    if (c == null) return <_RowSpec>[];
    final Map<String, dynamic> w = c['withCatalyst'] as Map<String, dynamic>;
    final Map<String, dynamic> wo = c['withoutCatalyst'] as Map<String, dynamic>;
    return <_RowSpec>[
      _RowSpec(
        label: 'WITH NEWS',
        right:
            '${_pct(w['winRate'])} • ${(w['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (w['avgRMultiple'] as num?)?.toDouble() ?? 0,
      ),
      _RowSpec(
        label: 'NO NEWS',
        right:
            '${_pct(wo['winRate'])} • ${(wo['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (wo['avgRMultiple'] as num?)?.toDouble() ?? 0,
      ),
      _RowSpec(
        label: 'LIFT',
        right: '${_pct(c['lift'])} edge',
        accentR: (c['lift'] as num?)?.toDouble() ?? 0,
      ),
    ];
  }

  List<_RowSpec> _flowRows(Map<String, dynamic> d) {
    final Map<String, dynamic>? f = d['flow'] as Map<String, dynamic>?;
    if (f == null) return <_RowSpec>[];
    final Map<String, dynamic> w =
        f['withFlowConfirmation'] as Map<String, dynamic>;
    final Map<String, dynamic> wo =
        f['withoutFlowConfirmation'] as Map<String, dynamic>;
    return <_RowSpec>[
      _RowSpec(
        label: 'CONFIRMED',
        right:
            '${_pct(w['winRate'])} • ${(w['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (w['avgRMultiple'] as num?)?.toDouble() ?? 0,
      ),
      _RowSpec(
        label: 'NOT CONFIRMED',
        right:
            '${_pct(wo['winRate'])} • ${(wo['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (wo['avgRMultiple'] as num?)?.toDouble() ?? 0,
      ),
      _RowSpec(
        label: 'LIFT',
        right: '${_pct(f['lift'])} edge',
        accentR: (f['lift'] as num?)?.toDouble() ?? 0,
      ),
    ];
  }

  List<_RowSpec> _detectorRows(Map<String, dynamic> d, {required bool top}) {
    final List<dynamic> r = (d[top ? 'topDetectors' : 'worstDetectors']
            as List<dynamic>?) ??
        <dynamic>[];
    return r.map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return _RowSpec(
        label: (m['key'] as String?) ?? '?',
        right:
            '${_pct(m['winRate'])} • ${(m['totalTrades'] as num?)?.toInt() ?? 0}',
        accentR: (m['avgRMultiple'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  String _pct(dynamic v) {
    if (v == null) return '—';
    final double d = (v as num).toDouble();
    return '${d.toStringAsFixed(0)}%';
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final int total = (data['totalTrades'] as num?)?.toInt() ?? 0;
    final int real = (data['realTrades'] as num?)?.toInt() ?? 0;
    final int shadow = (data['shadowTrades'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1A1714), Color(0xFF0D0B08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'WHAT THE SCANNER LEARNED',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total closed trades · $real real, $shadow shadow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.school_outlined,
              color: AppColors.gold, size: 36),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.rows,
  });
  final String title;
  final String subtitle;
  final List<_RowSpec> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14110D),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              'No data in this window',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            )
          else
            ...rows.map((_RowSpec r) {
              final Color accent = r.accentR > 0
                  ? const Color(0xFF8FD89F)
                  : r.accentR < 0
                      ? const Color(0xFFE07A6B)
                      : Colors.white70;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      r.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${r.accentR >= 0 ? "+" : ""}${r.accentR.toStringAsFixed(2)}R',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RowSpec {
  const _RowSpec({
    required this.label,
    required this.right,
    required this.accentR,
  });
  final String label;
  final String right;
  final double accentR;
}
