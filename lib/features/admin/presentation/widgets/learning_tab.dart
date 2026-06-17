import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const _scoreExplain =
      'Does a higher score predict a higher win rate? In a healthy model, win rate should rise monotonically as score climbs (50-60 → 60-70 → 70+). If 70+ wins LESS than 60-70, the scorer is overweighting noisy features — recalibrate.';
  static const _regimeExplain =
      'Bull / bear / chop expectancy. Most setups are regime-specific. If a detector is only profitable in bull, raise its grade threshold during bear or demote it conditionally.';
  static const _sessionExplain =
      'Morning (9:30-11:30) / lunch (11:30-13:30) / afternoon (13:30-16:00) win rates. Most day-mode detectors live in morning; if lunch is bleeding, GATE 4 may need to widen the lunch suppression window.';
  static const _catalystExplain =
      'Trades stamped with a news-catalyst boost vs trades without. Lift = with - without. Negative lift means the +5 catalyst score boost is mis-calibrated — the news isn\'t actually predictive.';
  static const _flowExplain =
      'Trades where Polygon options flow agreed with the signal direction vs trades where it didn\'t. Positive lift confirms cross-API flow is a useful signal worth keeping in the scorer.';
  static const _detectorExplain =
      'Per-detector profitability (min 5 trades). Top = positive expectancy contributors; worst = drag on the system. Use this view to rank what to retire, what to keep, what to amplify.';

  List<_RowSpec> _scoreBandRows(Map<String, dynamic> d) {
    final List<dynamic> bands = (d['scoreBands'] as List<dynamic>?) ?? <dynamic>[];
    return bands.map((dynamic e) {
      final Map<String, dynamic> m = e as Map<String, dynamic>;
      return _RowSpec(
        label: (m['band'] as String?) ?? '?',
        right:
            '${_pct(m['winRate'])} • ${(m['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (m['avgRMultiple'] as num?)?.toDouble() ?? 0,
        raw: m,
        sectionTitle: 'SCORE-BAND CALIBRATION',
        sectionExplain: _scoreExplain,
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
        raw: m,
        sectionTitle: 'REGIME EXPECTANCY',
        sectionExplain: _regimeExplain,
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
        raw: m,
        sectionTitle: 'SESSION EXPECTANCY',
        sectionExplain: _sessionExplain,
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
        raw: w,
        sectionTitle: 'NEWS CATALYST · WITH NEWS',
        sectionExplain: _catalystExplain,
      ),
      _RowSpec(
        label: 'NO NEWS',
        right:
            '${_pct(wo['winRate'])} • ${(wo['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (wo['avgRMultiple'] as num?)?.toDouble() ?? 0,
        raw: wo,
        sectionTitle: 'NEWS CATALYST · NO NEWS',
        sectionExplain: _catalystExplain,
      ),
      _RowSpec(
        label: 'LIFT',
        right: '${_pct(c['lift'])} edge',
        accentR: (c['lift'] as num?)?.toDouble() ?? 0,
        raw: c,
        sectionTitle: 'NEWS CATALYST · LIFT',
        sectionExplain: _catalystExplain,
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
        raw: w,
        sectionTitle: 'FLOW CONFIRMATION · CONFIRMED',
        sectionExplain: _flowExplain,
      ),
      _RowSpec(
        label: 'NOT CONFIRMED',
        right:
            '${_pct(wo['winRate'])} • ${(wo['totalTrades'] as num?)?.toInt() ?? 0} trades',
        accentR: (wo['avgRMultiple'] as num?)?.toDouble() ?? 0,
        raw: wo,
        sectionTitle: 'FLOW CONFIRMATION · NOT CONFIRMED',
        sectionExplain: _flowExplain,
      ),
      _RowSpec(
        label: 'LIFT',
        right: '${_pct(f['lift'])} edge',
        accentR: (f['lift'] as num?)?.toDouble() ?? 0,
        raw: f,
        sectionTitle: 'FLOW CONFIRMATION · LIFT',
        sectionExplain: _flowExplain,
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
        raw: m,
        sectionTitle: top ? 'TOP DETECTORS' : 'WORST DETECTORS',
        sectionExplain: _detectorExplain,
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
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: AppColors.obsidian,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  builder: (BuildContext c) =>
                      _LearningRowSheet(row: r, accent: accent),
                ),
                child: Padding(
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
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 16),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Drilldown sheet for a single learning-insights row. Shows the section
/// title + section-level interpretation, then every field on the row
/// map (winRate, totalTrades, avgRMultiple, plus anything else the
/// backend returns like avgHold, regime, session). Includes a copy-raw-
/// JSON action for power debugging.
class _LearningRowSheet extends StatelessWidget {
  const _LearningRowSheet({required this.row, required this.accent});
  final _RowSpec row;
  final Color accent;

  String _label(String k) {
    switch (k) {
      case 'band':
        return 'Score band';
      case 'regime':
        return 'Market regime';
      case 'session':
        return 'Session';
      case 'totalTrades':
        return 'Total trades';
      case 'wins':
        return 'Wins';
      case 'losses':
        return 'Losses';
      case 'winRate':
        return 'Win rate (%)';
      case 'avgRMultiple':
        return 'Avg R-multiple';
      case 'avgHoldHours':
        return 'Avg hold (hours)';
      case 'bestR':
        return 'Best R-multiple';
      case 'worstR':
        return 'Worst R-multiple';
      case 'key':
        return 'Detector key';
      case 'lift':
        return 'Lift';
      default:
        return k;
    }
  }

  String _format(dynamic v) {
    if (v == null) return '—';
    if (v is num) return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final keys = row.raw.keys.toList()..sort();
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext c, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              row.sectionTitle,
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              row.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Text(
                '${row.accentR >= 0 ? "+" : ""}${row.accentR.toStringAsFixed(2)}R avg · ${row.right}',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF14110D),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                row.sectionExplain,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'FULL REPORT',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            if (row.raw.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14110D),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Text(
                  'No raw fields attached to this row.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14110D),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < keys.length; i++) ...<Widget>[
                      if (i > 0)
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05),
                            height: 1),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Fixed-width label so a long value can't
                            // squeeze the label to a single character.
                            SizedBox(
                              width: 130,
                              child: Text(
                                _label(keys[i]),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Expanded + softWrap + maxLines ellipsis so
                            // long nested-map / list toString() values
                            // (which the API can return for some rows)
                            // don't overflow the Row by thousands of px.
                            Expanded(
                              child: Text(
                                _format(row.raw[keys[i]]),
                                textAlign: TextAlign.right,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text:
                        const JsonEncoder.withIndent('  ').convert(row.raw),
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Raw JSON copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 14, color: AppColors.gold),
                label: const Text(
                  'Copy raw JSON',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RowSpec {
  const _RowSpec({
    required this.label,
    required this.right,
    required this.accentR,
    this.raw = const <String, dynamic>{},
    this.sectionTitle = '',
    this.sectionExplain = '',
  });
  final String label;
  final String right;
  final double accentR;
  // Backing map for the drilldown sheet — carries every field the
  // backend sent for this row so the sheet can dump them all. Empty
  // map = drilldown will still open but only show synthetic stats.
  final Map<String, dynamic> raw;
  // Section context for the sheet header. Set by the row-builders below
  // so the sheet can show e.g. "REGIME · BULL" instead of just "BULL".
  final String sectionTitle;
  final String sectionExplain;
}
