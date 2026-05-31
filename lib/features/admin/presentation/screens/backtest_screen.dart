import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../providers/admin_providers.dart';

/// Backtest viewer — admin-only screen showing per-detector measured edge
/// from the backtest engine. Reads `setup_stats` via
/// `/api/admin/backtest/stats` and renders each (mode, kind) row with:
///   - win rate (with sample size)
///   - avg win % / avg loss %
///   - expectancy in % per trade (color-coded)
///   - regime breakdown (bull / bear / chop expectancy)
///
/// Tap "Run backtest" to force a fresh aggregation; takes ~30s on the
/// backend, then the list refreshes.
class BacktestScreen extends ConsumerStatefulWidget {
  const BacktestScreen({super.key});
  @override
  ConsumerState<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends ConsumerState<BacktestScreen> {
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
      // Sort by expectancy desc — best detectors at the top.
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
      final tickers = (res['tickers'] as num?)?.toInt() ?? 0;
      final groups = (res['groups'] as num?)?.toInt() ?? 0;
      final total = (res['total'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backtest done — $total trades across $groups detector kinds, $tickers mode×ticker combos.',
          ),
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
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        title: const Text(
          'BACKTEST RESULTS',
          style: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.gold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.settings),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Run backtest',
            onPressed: _running ? null : _runBacktest,
            icon: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  )
                : const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
            'Failed to load backtest stats:\n$_error',
            style: const TextStyle(color: AppColors.bearish),
          ),
        ),
      );
    }
    final rows = _rows ?? const <Map<String, dynamic>>[];
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.analytics_outlined,
                color: AppColors.gold, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No backtest stats yet.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the play button above to run the first backtest. Takes ~30 seconds, returns measured win rates per detector kind.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _running ? null : _runBacktest,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run backtest now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.obsidian,
              ),
            ),
          ],
        ),
      );
    }
    final positives = rows
        .where((r) => ((r['expectancyPct'] as num?) ?? 0) > 0)
        .length;
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        itemCount: rows.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _SummaryStrip(total: rows.length, positives: positives);
          }
          return _StatRow(row: rows[i - 1]);
        },
      ),
    );
  }
}

// ---------- summary header --------------------------------------------------

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.total, required this.positives});
  final int total;
  final int positives;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.analytics_outlined,
              color: AppColors.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            '$total detector kinds · ',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            '$positives profitable',
            style: const TextStyle(
              color: AppColors.bullish,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            ' · ${total - positives} losing',
            style: const TextStyle(
              color: AppColors.bearish,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- row ------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final mode = (row['mode'] as String?) ?? '';
    final kind = (row['kind'] as String?) ?? '';
    final n = (row['totalTrades'] as num?)?.toInt() ?? 0;
    final winRate = (row['winRate'] as num?)?.toDouble() ?? 0;
    final avgWin = (row['avgWinPct'] as num?)?.toDouble() ?? 0;
    final avgLoss = (row['avgLossPct'] as num?)?.toDouble() ?? 0;
    final expectancy = (row['expectancyPct'] as num?)?.toDouble() ?? 0;
    final byRegime = (row['byRegime'] as Map<String, dynamic>?) ?? const {};

    Color expectancyColor;
    if (expectancy >= 0.15) {
      expectancyColor = AppColors.bullish;
    } else if (expectancy >= 0) {
      expectancyColor = AppColors.gold;
    } else {
      expectancyColor = AppColors.bearish;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expectancyColor.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: mode + kind + expectancy badge
          Row(
            children: <Widget>[
              _ModePill(mode: mode),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kind.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: expectancyColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: expectancyColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${expectancy >= 0 ? "+" : ""}${expectancy.toStringAsFixed(2)}%/trade',
                  style: TextStyle(
                    color: expectancyColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            children: <Widget>[
              _MicroStat(
                label: 'WIN',
                value: '${winRate.toStringAsFixed(1)}%',
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 14),
              _MicroStat(
                label: 'n',
                value: '$n',
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              _MicroStat(
                label: 'AVG WIN',
                value: '+${avgWin.toStringAsFixed(2)}%',
                color: AppColors.bullish,
              ),
              const SizedBox(width: 14),
              _MicroStat(
                label: 'AVG LOSS',
                value: '-${avgLoss.toStringAsFixed(2)}%',
                color: AppColors.bearish,
              ),
            ],
          ),
          if (byRegime.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            const Divider(color: AppColors.steel, height: 1),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _RegimeStat(
                  label: 'BULL',
                  bucket: byRegime['bull'] as Map<String, dynamic>?,
                ),
                const SizedBox(width: 8),
                _RegimeStat(
                  label: 'BEAR',
                  bucket: byRegime['bear'] as Map<String, dynamic>?,
                ),
                const SizedBox(width: 8),
                _RegimeStat(
                  label: 'CHOP',
                  bucket: byRegime['chop'] as Map<String, dynamic>?,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final pretty = mode.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Text(
        pretty,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  const _MicroStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _RegimeStat extends StatelessWidget {
  const _RegimeStat({required this.label, required this.bucket});
  final String label;
  final Map<String, dynamic>? bucket;
  @override
  Widget build(BuildContext context) {
    final exp = (bucket?['expectancyPct'] as num?)?.toDouble() ?? 0;
    final n = (bucket?['totalTrades'] as num?)?.toInt() ?? 0;
    final hasData = n > 0;
    final Color color = !hasData
        ? AppColors.textTertiary
        : exp >= 0
            ? AppColors.bullish
            : AppColors.bearish;
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.obsidian,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: color.withValues(alpha: hasData ? 0.4 : 0.2)),
        ),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasData
                    ? '${exp >= 0 ? "+" : ""}${exp.toStringAsFixed(2)}% (n=$n)'
                    : 'no data',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
