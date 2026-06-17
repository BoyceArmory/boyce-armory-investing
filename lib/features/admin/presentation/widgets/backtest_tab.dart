import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/admin_providers.dart';

/// Backtest tab — same content as the standalone BacktestScreen but
/// stripped of Scaffold/AppBar so it embeds inside the AdminDashboard
/// TabBarView. Lets admins compare detector edge without leaving the
/// dashboard.
class BacktestTab extends ConsumerStatefulWidget {
  const BacktestTab({super.key});
  @override
  ConsumerState<BacktestTab> createState() => _BacktestTabState();
}

class _BacktestTabState extends ConsumerState<BacktestTab> {
  List<Map<String, dynamic>>? _rows;
  bool _loading = false;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final rows = await repo.fetchBacktestStats();
      rows.sort((a, b) => ((b['expectancyPct'] as num?) ?? 0)
          .compareTo((a['expectancyPct'] as num?) ?? 0));
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Open a bottom-sheet drilldown showing every field on the backtest
  /// row plus a copy-raw-JSON action. The compact row only shows mode +
  /// kind + win rate + expectancy; everything else (sample size, avg
  /// hold, best/worst R-multiple, last-updated, cooldown) lives in the
  /// raw doc and is invaluable when triaging a detector that's drifting.
  void _openReport(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.obsidian,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext c) => _BacktestReportSheet(row: row),
    );
  }

  Future<void> _runBacktest() async {
    HapticFeedback.mediumImpact();
    setState(() => _running = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.runBacktest();
      if (!mounted) return;
      final total = (res['total'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backtest done — $total trades aggregated.'),
          backgroundColor: AppColors.bullish,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backtest failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null && _rows == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load: $_error',
            style: const TextStyle(color: AppColors.bearish),
          ),
        ),
      );
    }
    final rows = _rows ?? const <Map<String, dynamic>>[];
    final positives = rows
        .where((r) => ((r['expectancyPct'] as num?) ?? 0) > 0)
        .length;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: AppColors.graphite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.analytics_outlined,
                          color: AppColors.gold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${rows.length} kinds',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· $positives win · ${rows.length - positives} lose',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _running ? null : _runBacktest,
                icon: _running
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.obsidian),
                      )
                    : const Icon(Icons.play_arrow, size: 16),
                label: const Text('Run', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.obsidian,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.graphite,
            onRefresh: _load,
            child: rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(height: 80),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No backtest stats yet. Tap Run to compute.',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CompactStatRow(
                      row: rows[i],
                      onTap: () => _openReport(rows[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CompactStatRow extends StatelessWidget {
  const _CompactStatRow({required this.row, this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mode = (row['mode'] as String?) ?? '';
    final kind = (row['kind'] as String?) ?? '';
    final n = (row['totalTrades'] as num?)?.toInt() ?? 0;
    final winRate = (row['winRate'] as num?)?.toDouble() ?? 0;
    final expectancy = (row['expectancyPct'] as num?)?.toDouble() ?? 0;

    Color color;
    if (expectancy >= 0.15) {
      color = AppColors.bullish;
    } else if (expectancy >= 0) {
      color = AppColors.gold;
    } else {
      color = AppColors.bearish;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: Text(
              mode.toUpperCase(),
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  kind.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${winRate.toStringAsFixed(1)}% win · n=$n',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${expectancy >= 0 ? "+" : ""}${expectancy.toStringAsFixed(2)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 18),
        ],
      ),
      ),
    );
  }
}

/// Full-detail bottom sheet for a single backtest row. Dumps every
/// field returned by /api/admin/backtest/stats for that (mode, kind)
/// combo, with friendly labels + a copy-raw-JSON action. Sheet is
/// intentionally scrollable + tall — designed for triage, not glance.
class _BacktestReportSheet extends StatelessWidget {
  const _BacktestReportSheet({required this.row});
  final Map<String, dynamic> row;

  String _label(String k) {
    switch (k) {
      case 'mode':
        return 'Mode';
      case 'kind':
        return 'Detector kind';
      case 'totalTrades':
        return 'Total trades';
      case 'wins':
        return 'Wins';
      case 'losses':
        return 'Losses';
      case 'winRate':
        return 'Win rate (%)';
      case 'expectancyPct':
        return 'Expectancy (%)';
      case 'avgRMultiple':
        return 'Avg R-multiple';
      case 'bestR':
        return 'Best R-multiple';
      case 'worstR':
        return 'Worst R-multiple';
      case 'avgHoldHours':
        return 'Avg hold (hours)';
      case 'lastUpdated':
        return 'Last updated';
      case 'sampleSizeWarning':
        return 'Sample-size warning';
      case 'cooldownUntil':
        return 'Cooldown until';
      case 'demotedAt':
        return 'Demoted at';
      default:
        return k;
    }
  }

  String _format(dynamic v) {
    if (v == null) return '—';
    if (v is num) {
      // Show one decimal for percent-shaped fields, two for R-multiples.
      return v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final mode = (row['mode'] as String?) ?? '';
    final kind = (row['kind'] as String?) ?? '';
    final expectancy = (row['expectancyPct'] as num?)?.toDouble() ?? 0;
    final winRate = (row['winRate'] as num?)?.toDouble() ?? 0;
    final n = (row['totalTrades'] as num?)?.toInt() ?? 0;
    Color verdict;
    String verdictLabel;
    String verdictBody;
    if (n < 5) {
      verdict = AppColors.textTertiary;
      verdictLabel = 'NEEDS MORE DATA';
      verdictBody =
          'Only $n trades. Anything under 5 is noise — wait for more before tuning this detector.';
    } else if (expectancy >= 0.15 && winRate >= 55) {
      verdict = AppColors.bullish;
      verdictLabel = 'EDGE CONFIRMED';
      verdictBody =
          'Win rate ${winRate.toStringAsFixed(1)}% + expectancy ${expectancy.toStringAsFixed(2)}% over $n trades. Keep promoting.';
    } else if (expectancy >= 0) {
      verdict = AppColors.gold;
      verdictLabel = 'MARGINAL';
      verdictBody =
          'Expectancy positive but thin. Watch for drift; consider tightening grade threshold.';
    } else {
      verdict = AppColors.bearish;
      verdictLabel = 'BLEEDING';
      verdictBody =
          'Expectancy ${expectancy.toStringAsFixed(2)}% over $n trades. Demote or rework before next cycle.';
    }
    // Sort the fields so the header + verdict block has a stable order
    // and everything else trails in alpha. mode/kind are surfaced as the
    // sheet header so they're omitted from the table.
    final keys = row.keys.where((k) => k != 'mode' && k != 'kind').toList()
      ..sort();
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ---- Header
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Text(
                    mode.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kind.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ---- Verdict
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: verdict.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: verdict.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    verdictLabel,
                    style: TextStyle(
                      color: verdict,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    verdictBody,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // ---- All raw fields
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.graphite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.steel),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < keys.length; i++) ...<Widget>[
                    if (i > 0)
                      const Divider(color: AppColors.steel, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Label fixed-width on the left so long values
                          // don't squeeze it down to one character.
                          SizedBox(
                            width: 130,
                            child: Text(
                              _label(keys[i]),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Value gets the rest. Long nested-map/list
                          // toString() output would overflow the row by
                          // thousands of px without Expanded + softWrap
                          // + maxLines cap. Keep maxLines generous so
                          // multi-line JSON-shaped strings stay readable.
                          Expanded(
                            child: Text(
                              _format(row[keys[i]]),
                              textAlign: TextAlign.right,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
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
                      text: const JsonEncoder.withIndent('  ').convert(row)));
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
