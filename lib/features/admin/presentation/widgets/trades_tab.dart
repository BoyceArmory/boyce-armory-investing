import 'package:flutter/material.dart';
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

class _ClosedTradesSection extends ConsumerWidget {
  const _ClosedTradesSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(closedTradesProvider);
    return RefreshIndicator(
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
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.title, required this.subtitle, required this.tail});
  final String title;
  final String subtitle;
  final Widget tail;
  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
      ),
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
