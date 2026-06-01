import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Reverse-chronological audit log feed (admin_logs collection).
///
/// May 2026 rework: added client-side filters so admins can search the
/// log instead of scrolling 500 rows.
///   - Free-text query (matches action + actor + target + extras)
///   - Action-prefix chips ("push.", "alerts.", "trades.", "detectors.")
///   - Time-window selector (1h / 24h / 7d / all)
///
/// Filters apply purely on the already-loaded list — no extra API calls.
class AuditTab extends ConsumerStatefulWidget {
  const AuditTab({super.key});
  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<AuditTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _prefix = 'all';
  String _window = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const Map<String, String> _prefixOptions = <String, String>{
    'all': 'All',
    'push': 'Push',
    'alerts': 'Alerts',
    'trades': 'Trades',
    'detectors': 'Detectors',
    'scanner': 'Scanner',
    'backtest': 'Backtest',
    'system': 'System / flags',
  };

  static const Map<String, Duration?> _windowOptions = <String, Duration?>{
    'all': null,
    '1h': Duration(hours: 1),
    '24h': Duration(hours: 24),
    '7d': Duration(days: 7),
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditLogsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(auditLogsProvider);
        await ref.read(auditLogsProvider.future);
      },
      child: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => ErrorState(
          message: 'Could not load audit log',
          details: e.toString(),
          onRetry: () => ref.invalidate(auditLogsProvider),
        ),
        data: (list) {
          final filtered = _applyFilters(list);
          return Column(
            children: <Widget>[
              _FilterBar(
                searchCtrl: _searchCtrl,
                prefix: _prefix,
                window: _window,
                prefixOptions: _prefixOptions,
                windowOptions: _windowOptions.keys.toList(),
                total: list.length,
                shown: filtered.length,
                onSearchChanged: (_) => setState(() {}),
                onPrefix: (p) => setState(() => _prefix = p),
                onWindow: (w) => setState(() => _window = w),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const <Widget>[
                          SizedBox(height: 80),
                          Center(
                              child: Text(
                            'No matching audit entries.',
                            style: TextStyle(color: AppColors.textTertiary),
                          )),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _AuditRow(entry: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final cutoff = _windowOptions[_window];
    final cutoffTime =
        cutoff != null ? DateTime.now().subtract(cutoff) : null;
    return rows.where((e) {
      final action = (e['action'] ?? '').toString();
      // Time-window filter
      if (cutoffTime != null) {
        final t = DateTime.tryParse((e['at'] ?? '').toString());
        if (t == null || t.isBefore(cutoffTime)) return false;
      }
      // Prefix filter
      if (_prefix != 'all' && !action.startsWith(_prefix)) return false;
      // Free-text filter — searches across all string-ish fields
      if (q.isNotEmpty) {
        final haystack = e.entries
            .map((kv) => '${kv.key}=${kv.value}')
            .join(' ')
            .toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList(growable: false);
  }
}

// ---------------- filter bar --------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchCtrl,
    required this.prefix,
    required this.window,
    required this.prefixOptions,
    required this.windowOptions,
    required this.total,
    required this.shown,
    required this.onSearchChanged,
    required this.onPrefix,
    required this.onWindow,
  });
  final TextEditingController searchCtrl;
  final String prefix;
  final String window;
  final Map<String, String> prefixOptions;
  final List<String> windowOptions;
  final int total;
  final int shown;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onPrefix;
  final ValueChanged<String> onWindow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: <Widget>[
          TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search action, actor, target, extras...',
              hintStyle:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              filled: true,
              fillColor: AppColors.graphite,
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textTertiary, size: 18),
              suffixIcon: searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.textTertiary, size: 16),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      },
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.steel),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.steel),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.gold, width: 1),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Time-window chips (compact)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final w in windowOptions) ...<Widget>[
                  _Chip(
                    label: w == 'all' ? 'All time' : 'Last $w',
                    selected: window == w,
                    onTap: () => onWindow(w),
                  ),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 18,
                  color: AppColors.steel,
                ),
                const SizedBox(width: 6),
                for (final entry in prefixOptions.entries) ...<Widget>[
                  _Chip(
                    label: entry.value,
                    selected: prefix == entry.key,
                    onTap: () => onPrefix(entry.key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              total == shown
                  ? '$shown entries'
                  : '$shown of $total entries (filtered)',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.18)
                : AppColors.graphite,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : AppColors.steel,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- existing row renderer (unchanged) ----------------------

class _AuditRow extends StatefulWidget {
  const _AuditRow({required this.entry});
  final Map<String, dynamic> entry;
  @override
  State<_AuditRow> createState() => _AuditRowState();
}

class _AuditRowState extends State<_AuditRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final action = (entry['action'] ?? 'unknown').toString();
    final actor = (entry['actor'] ?? 'system').toString();
    final target = entry['target'];
    final at = entry['at']?.toString();
    DateTime? t;
    if (at != null) t = DateTime.tryParse(at);
    final ago = t == null ? '—' : _agoShort(t);
    final color = _actionColor(action);

    final extras = <String, dynamic>{...entry}
      ..remove('id')
      ..remove('action')
      ..remove('actor')
      ..remove('target')
      ..remove('at');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: extras.isEmpty ? null : () => setState(() => _expanded = !_expanded),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(
                color: _expanded
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.steel),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Text(action,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      target == null ? '' : 'target: $target',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (extras.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  Text(ago,
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text('by $actor',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              if (extras.isNotEmpty && !_expanded) ...[
                const SizedBox(height: 4),
                Text(
                  extras.entries
                      .map((e) => '${e.key}=${e.value}')
                      .join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
              ],
              if (extras.isNotEmpty && _expanded) ...[
                const SizedBox(height: 8),
                _MetaPanel(meta: extras),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    if (action.startsWith('set_disabled') || action.contains('hide')) {
      return AppColors.bearish;
    }
    if (action.startsWith('set_role') || action.startsWith('set_tier')) {
      return AppColors.gold;
    }
    if (action.contains('promote') || action.contains('create')) {
      return AppColors.bullish;
    }
    if (action.startsWith('trigger_') || action.startsWith('run_')) {
      return AppColors.info;
    }
    if (action.startsWith('set_flags')) return AppColors.warning;
    if (action.startsWith('system.') || action.contains('auto-demote')) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }
}

/// Expanded meta panel — pretty-printed JSON + a copy button. Used when the
/// user taps an audit row that has extra context (e.g. auto-demote details,
/// promote-scanner alert payloads, push announcement results).
class _MetaPanel extends StatelessWidget {
  const _MetaPanel({required this.meta});
  final Map<String, dynamic> meta;

  String _pretty() {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(meta);
    } catch (_) {
      return meta.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pretty = _pretty();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'META',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: pretty));
                  HapticFeedback.selectionClick();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12, color: AppColors.gold),
                      SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            pretty,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10.5,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}
