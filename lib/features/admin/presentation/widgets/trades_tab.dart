import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Trades tab — active + closed lists, close a trade from active.
class TradesTab extends ConsumerStatefulWidget {
  const TradesTab({super.key});
  @override
  ConsumerState<TradesTab> createState() => _TradesTabState();
}

class _TradesTabState extends ConsumerState<TradesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _sub = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.steel),
          ),
          padding: const EdgeInsets.all(3),
          child: TabBar(
            controller: _sub,
            indicator: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            tabs: const [Tab(height: 32, text: 'Active'), Tab(height: 32, text: 'Closed')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: const [_ActiveTradesSection(), _ClosedTradesSection()],
          ),
        ),
      ],
    );
  }
}

class _ActiveTradesSection extends ConsumerStatefulWidget {
  const _ActiveTradesSection();
  @override
  ConsumerState<_ActiveTradesSection> createState() => _ActiveTradesSectionState();
}

class _ActiveTradesSectionState extends ConsumerState<_ActiveTradesSection> {
  String? _busyId;

  Future<void> _close(String id) async {
    final res = await showDialog<_CloseResult>(
      context: context,
      builder: (_) => const _CloseTradeDialog(),
    );
    if (res == null) return;
    setState(() => _busyId = id);
    try {
      await ref.read(adminRepositoryProvider).closeTrade(id, res.exit, notes: res.notes);
      ref.invalidate(activeTradesProvider);
      ref.invalidate(closedTradesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Trade closed @ ${res.exit}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Close failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeTradesProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(activeTradesProvider);
        await ref.read(activeTradesProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => ErrorState(
          message: 'Could not load active trades',
          details: e.toString(),
          onRetry: () => ref.invalidate(activeTradesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No open trades.',
                    style: TextStyle(color: AppColors.textTertiary))),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = list[i];
              final id = (t['id'] ?? '').toString();
              return _TradeRow(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: AppColors.obsidian,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  builder: (BuildContext c) => _ClosedTradeSheet(trade: t),
                ),
                title: '${t['symbol']} · ${t['direction']}',
                subtitle:
                    'entry ${t['entry']}${t['target'] != null ? " → ${t['target']}" : ""}${t['stop'] != null ? " · stop ${t['stop']}" : ""}',
                tail: ElevatedButton.icon(
                  onPressed: _busyId == id ? null : () => _close(id),
                  icon: _busyId == id
                      ? const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                        )
                      : const Icon(Icons.close, size: 14),
                  label: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.obsidian,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ClosedTradesSection extends ConsumerStatefulWidget {
  const _ClosedTradesSection();
  @override
  ConsumerState<_ClosedTradesSection> createState() =>
      _ClosedTradesSectionState();
}

class _ClosedTradesSectionState
    extends ConsumerState<_ClosedTradesSection> {
  Future<void> _openBulkImport() async {
    final json = await showDialog<String>(
      context: context,
      builder: (_) => const _BulkImportDialog(),
    );
    if (json == null) return;
    List<dynamic> parsed;
    try {
      final dynamic decoded = _safeJsonDecode(json);
      // Accept either a top-level array OR {"trades": [...]}.
      if (decoded is List) {
        parsed = decoded;
      } else if (decoded is Map && decoded['trades'] is List) {
        parsed = decoded['trades'] as List;
      } else {
        throw const FormatException(
            'Expected an array of trades or an object with a "trades" array');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invalid JSON: $e'),
            backgroundColor: AppColors.bearish),
      );
      return;
    }
    try {
      final trades = parsed
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      final res = await ref
          .read(adminRepositoryProvider)
          .bulkImportTrades(trades);
      if (!mounted) return;
      final imported = res['imported'] ?? 0;
      final skipped = res['skipped'] ?? 0;
      final errors = res['errors'] is List
          ? (res['errors'] as List).length
          : 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Imported $imported, skipped $skipped, errors $errors.'),
          backgroundColor:
              errors == 0 ? AppColors.bullish : AppColors.warning,
        ),
      );
      ref.invalidate(closedTradesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.bearish),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(closedTradesProvider);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openBulkImport,
              icon: const Icon(Icons.file_upload_outlined,
                  size: 16, color: AppColors.gold),
              label: const Text('Bulk import JSON'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(closedTradesProvider);
        await ref.read(closedTradesProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => ErrorState(
          message: 'Could not load closed trades',
          details: e.toString(),
          onRetry: () => ref.invalidate(closedTradesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No closed trades.',
                    style: TextStyle(color: AppColors.textTertiary))),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = list[i];
              final pnlPct = (t['pnlPct'] as num?)?.toDouble();
              final pnlAbs = (t['pnlAbs'] as num?)?.toDouble();
              final result = (t['result'] ?? '').toString();
              final color = result == 'win'
                  ? AppColors.bullish
                  : (result == 'loss' ? AppColors.bearish : AppColors.textSecondary);
              return _TradeRow(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: AppColors.obsidian,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  builder: (BuildContext c) =>
                      _ClosedTradeSheet(trade: t),
                ),
                title: '${t['symbol']} · ${t['direction']}',
                subtitle:
                    'entry ${t['entry']} → exit ${t['exit']}${pnlPct != null ? "  (${pnlPct.toStringAsFixed(2)}%)" : ""}',
                tail: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(result.toUpperCase(),
                          style: TextStyle(
                              color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    if (pnlAbs != null) ...[
                      const SizedBox(height: 4),
                      Text('${pnlAbs >= 0 ? "+" : ""}${pnlAbs.toStringAsFixed(2)}',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
        ),
      ],
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({
    required this.title,
    required this.subtitle,
    required this.tail,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final Widget tail;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          tail,
          if (onTap != null) ...const <Widget>[
            SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: AppColors.textTertiary, size: 18),
          ],
        ],
      ),
        ),
      ),
    );
  }
}

/// Bottom-sheet drilldown for a closed trade. Shows the full lifecycle —
/// entry/exit, P&L %, P&L $, R-multiple, regime + session + scoreAtFire
/// (the learning-loop signals), sizing snapshot, suggested contract,
/// and the full timestamps. Same pattern as the backtest + learning
/// drilldowns: fixed-label table on the left, ellipsizing value column
/// on the right, raw-JSON copy at the bottom. Verdict block at the top
/// summarises the trade as WIN / LOSS / BREAKEVEN with one-line context.
class _ClosedTradeSheet extends StatelessWidget {
  const _ClosedTradeSheet({required this.trade});
  final Map<String, dynamic> trade;

  String _label(String k) {
    switch (k) {
      case 'symbol':
        return 'Symbol';
      case 'direction':
        return 'Direction';
      case 'mode':
        return 'Mode';
      case 'kind':
        return 'Detector kind';
      case 'entry':
        return 'Entry';
      case 'exit':
        return 'Exit';
      case 'target':
        return 'Target';
      case 'stop':
        return 'Stop';
      case 'pnlPct':
        return 'P&L (%)';
      case 'pnlAbs':
        return 'P&L (\$)';
      case 'rMultiple':
        return 'R-multiple';
      case 'result':
        return 'Result';
      case 'regime':
        return 'Regime at entry';
      case 'session':
        return 'Session';
      case 'scoreAtFire':
        return 'Score at fire';
      case 'grade':
        return 'Grade';
      case 'sizing':
        return 'Sizing snapshot';
      case 'suggestedContract':
        return 'Suggested contract';
      case 'openedAt':
        return 'Opened at';
      case 'closedAt':
        return 'Closed at';
      case 'durationHours':
        return 'Duration (hours)';
      case 'isShadow':
        return 'Shadow trade?';
      case 'tookByUid':
        return 'Taken by (uid)';
      case 'notes':
        return 'Notes';
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
    final result = (trade['result'] ?? '').toString().toLowerCase();
    final pnlPct = (trade['pnlPct'] as num?)?.toDouble();
    final pnlAbs = (trade['pnlAbs'] as num?)?.toDouble();
    final rMult = (trade['rMultiple'] as num?)?.toDouble();
    final symbol = (trade['symbol'] ?? '').toString();
    final direction = (trade['direction'] ?? '').toString();

    // An open position has no result + no closedAt. We surface it as
    // OPEN with the planned target/stop instead of pretending the trade
    // resolved at breakeven. Detection is "trade is still active" =
    // no result + no closedAt timestamp.
    final isOpen = (trade['closedAt'] == null) &&
        (result.isEmpty || result == 'open' || result == 'active');

    Color verdict;
    String verdictLabel;
    String verdictBody;
    if (isOpen) {
      verdict = AppColors.gold;
      verdictLabel = 'OPEN';
      final target = trade['target']?.toString();
      final stop = trade['stop']?.toString();
      verdictBody =
          'Position is still open. Plan: target ${target ?? "—"}, stop ${stop ?? "—"}.';
    } else if (result == 'win') {
      verdict = AppColors.bullish;
      verdictLabel = 'WIN';
      verdictBody = pnlPct != null
          ? '+${pnlPct.toStringAsFixed(2)}% · ${rMult != null ? "${rMult >= 0 ? "+" : ""}${rMult.toStringAsFixed(2)}R" : "R-multiple n/a"}'
          : 'Closed positive.';
    } else if (result == 'loss') {
      verdict = AppColors.bearish;
      verdictLabel = 'LOSS';
      verdictBody = pnlPct != null
          ? '${pnlPct.toStringAsFixed(2)}% · ${rMult != null ? "${rMult.toStringAsFixed(2)}R" : "R-multiple n/a"}'
          : 'Closed negative.';
    } else {
      verdict = AppColors.gold;
      verdictLabel = 'BREAKEVEN';
      verdictBody = 'Closed flat — neither stop nor target struck cleanly.';
    }

    // mode + result get rendered in the verdict pill; keep the rest in
    // alpha order in the table so admins can scan predictably.
    final keys = trade.keys
        .where((k) => k != 'symbol' && k != 'direction' && k != 'result')
        .toList()
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
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: verdict.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: verdict),
                  ),
                  child: Text(
                    verdictLabel,
                    style: TextStyle(
                      color: verdict,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$symbol · $direction',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (pnlAbs != null)
                  Text(
                    '${pnlAbs >= 0 ? "+" : ""}\$${pnlAbs.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: verdict,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: verdict.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: verdict.withValues(alpha: 0.55)),
              ),
              child: Text(
                verdictBody,
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
                      padding:
                          const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 140,
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
                              _format(trade[keys[i]]),
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
                    text:
                        const JsonEncoder.withIndent('  ').convert(trade),
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

class _CloseResult {
  _CloseResult(this.exit, this.notes);
  final double exit;
  final String? notes;
}

class _CloseTradeDialog extends StatefulWidget {
  const _CloseTradeDialog();
  @override
  State<_CloseTradeDialog> createState() => _CloseTradeDialogState();
}

class _CloseTradeDialogState extends State<_CloseTradeDialog> {
  final _exit = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _exit.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.graphite,
      title: const Text('Close trade', style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _exit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Exit price',
              labelStyle: TextStyle(color: AppColors.textTertiary),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle: TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final v = double.tryParse(_exit.text.trim());
            if (v == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exit price required')),
              );
              return;
            }
            Navigator.of(context).pop(
              _CloseResult(v, _notes.text.trim().isEmpty ? null : _notes.text.trim()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.obsidian,
          ),
          child: const Text('Close trade'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bulk import (closed trades)
// ---------------------------------------------------------------------------

/// Safe JSON decode that returns the parsed dynamic or rethrows a
/// FormatException with a cleaner message. Wrapping `jsonDecode` lets the
/// caller surface "Invalid JSON: …" snackbars instead of dart:core errors.
dynamic _safeJsonDecode(String s) {
  try {
    return jsonDecode(s);
  } on FormatException catch (e) {
    throw FormatException(e.message);
  }
}

/// Dialog for pasting an array of closed trades as JSON. Accepts either:
///   [ {symbol, direction, entry, exit, ...}, ... ]
/// or a wrapper:
///   { "trades": [ {...}, ... ] }
///
/// Each trade should include at minimum: symbol, direction ("call"/"put" or
/// "long"/"short"), entry, exit, closedAt (ISO string or epoch ms). An
/// optional `idempotencyKey` lets you safely re-paste without dupes — the
/// backend de-dupes on that key.
class _BulkImportDialog extends StatefulWidget {
  const _BulkImportDialog();
  @override
  State<_BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<_BulkImportDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final txt = data?.text;
    if (txt == null || txt.isEmpty) return;
    setState(() => _ctrl.text = txt);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.graphite,
      title: Row(
        children: [
          const Expanded(
            child: Text(
              'Bulk import closed trades',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          ),
          IconButton(
            tooltip: 'Paste from clipboard',
            onPressed: _pasteFromClipboard,
            icon: const Icon(Icons.content_paste,
                color: AppColors.gold, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste a JSON array of trades, or an object with a "trades" key.\n'
              'Each trade: { symbol, direction, entry, exit, closedAt, '
              'qty?, idempotencyKey?, contract? }',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                minLines: 10,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: '[\n  {"symbol":"AAPL","direction":"call",'
                      '"entry":189.50,"exit":192.30,'
                      '"closedAt":"2026-05-30T20:01:00Z"}\n]',
                  hintStyle: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: AppColors.obsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.steel),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.steel),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.gold),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final txt = _ctrl.text.trim();
            if (txt.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paste some JSON first')),
              );
              return;
            }
            Navigator.of(context).pop(txt);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.obsidian,
          ),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
