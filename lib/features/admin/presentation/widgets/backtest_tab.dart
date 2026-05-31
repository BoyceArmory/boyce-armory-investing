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
                    itemBuilder: (_, i) => _CompactStatRow(row: rows[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CompactStatRow extends StatelessWidget {
  const _CompactStatRow({required this.row});
  final Map<String, dynamic> row;

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

    return Container(
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
        ],
      ),
    );
  }
}
