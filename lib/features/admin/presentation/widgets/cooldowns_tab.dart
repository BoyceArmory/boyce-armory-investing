import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/admin_providers.dart';

/// Live cooldown viewer — every (mode, symbol, kind) currently
/// suppressed by the in-memory cooldown table. The "why didn't I get an
/// alert on AAPL today?" debugging surface that previously required
/// ssh'ing into the box.
///
/// Auto-refreshes on pull-down. Mode filter chips at the top let the
/// admin scope to swing / leaps. Tapping a row opens a drilldown
/// sheet (same pattern as backtest + learning + errors) with the full
/// row map + copy-raw-JSON.
class CooldownsTab extends ConsumerStatefulWidget {
  const CooldownsTab({super.key});
  @override
  ConsumerState<CooldownsTab> createState() => _CooldownsTabState();
}

class _CooldownsTabState extends ConsumerState<CooldownsTab> {
  List<Map<String, dynamic>>? _rows;
  bool _loading = false;
  String? _error;
  String _mode = 'all';

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
      final rows = await ref.read(adminRepositoryProvider).fetchCooldowns();
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final all = _rows ?? const <Map<String, dynamic>>[];
    if (_mode == 'all') return all;
    return all.where((r) => (r['mode'] ?? '') == _mode).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_error != null && _rows == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Failed to load cooldowns: $_error',
          style: const TextStyle(color: AppColors.bearish),
        ),
      );
    }
    final filtered = _filtered;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: <Widget>[
              _ModeChip(
                label: 'All',
                value: 'all',
                current: _mode,
                onTap: () => setState(() => _mode = 'all'),
                count: (_rows ?? const <Map<String, dynamic>>[]).length,
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: 'Swing',
                value: 'swing',
                current: _mode,
                onTap: () => setState(() => _mode = 'swing'),
                count: (_rows ?? const <Map<String, dynamic>>[])
                    .where((r) => r['mode'] == 'swing')
                    .length,
              ),
              const SizedBox(width: 6),
              _ModeChip(
                label: 'LEAPS',
                value: 'leaps',
                current: _mode,
                onTap: () => setState(() => _mode = 'leaps'),
                count: (_rows ?? const <Map<String, dynamic>>[])
                    .where((r) => r['mode'] == 'leaps')
                    .length,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.graphite,
            onRefresh: _load,
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(height: 80),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No active cooldowns in this scope. The scanner is free to fire any setup.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _CooldownRow(
                      row: filtered[i],
                      onTap: () => _openSheet(filtered[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _openSheet(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.obsidian,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext c) => _CooldownDetailSheet(row: row),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
    required this.count,
  });
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;
  final int count;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : AppColors.textTertiary.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          '$label · $count',
          style: TextStyle(
            color: selected ? AppColors.gold : AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _CooldownRow extends StatelessWidget {
  const _CooldownRow({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mode = (row['mode'] as String?) ?? '';
    final symbol = (row['symbol'] as String?) ?? '';
    final kind = (row['kind'] as String?) ?? '';
    final minutesAgo = (row['minutesAgo'] as num?)?.toInt() ?? 0;
    final until = (row['minutesUntilExpiry'] as num?)?.toInt() ?? 0;
    final lastScore = (row['lastScore'] as num?)?.toDouble() ?? 0;
    final failed = row['failedAt'] != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: failed
                  ? AppColors.bearish.withValues(alpha: 0.45)
                  : AppColors.steel,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
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
                    Row(
                      children: <Widget>[
                        Text(
                          symbol,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            kind.replaceAll('_', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (failed) ...const <Widget>[
                          SizedBox(width: 6),
                          Icon(Icons.error_outline,
                              size: 12, color: AppColors.bearish),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'score ${lastScore.toStringAsFixed(0)} · ${minutesAgo}m ago · ${until}m left',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drilldown — dumps the row + copy raw JSON. Same shell as the other
/// admin drilldowns we built this push so admins know what to expect.
class _CooldownDetailSheet extends StatelessWidget {
  const _CooldownDetailSheet({required this.row});
  final Map<String, dynamic> row;

  String _label(String k) {
    switch (k) {
      case 'mode':
        return 'Mode';
      case 'symbol':
        return 'Symbol';
      case 'kind':
        return 'Detector kind';
      case 'lastScore':
        return 'Last score';
      case 'lastPublishedAt':
        return 'Last published at';
      case 'minutesAgo':
        return 'Minutes ago';
      case 'minutesUntilExpiry':
        return 'Minutes until expiry';
      case 'fireCount':
        return 'Fire count today';
      case 'failedAt':
        return 'Failed at';
      case 'key':
        return 'Cooldown key';
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
    final symbol = (row['symbol'] ?? '').toString();
    final kind = (row['kind'] ?? '').toString();
    final until = (row['minutesUntilExpiry'] as num?)?.toInt() ?? 0;
    final keys = row.keys.toList()..sort();
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
            Text(
              '$symbol · ${kind.replaceAll("_", " ")}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
              ),
              child: Text(
                until > 0
                    ? 'This setup is suppressed for another $until minute${until == 1 ? "" : "s"}. The scanner will skip same-day re-fires unless the score jumps by 10+, price extends 1R past entry, or the cooldown expires.'
                    : 'Cooldown expired — next fire will publish.',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
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
                          SizedBox(
                            width: 150,
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
                    text: const JsonEncoder.withIndent('  ').convert(row),
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
