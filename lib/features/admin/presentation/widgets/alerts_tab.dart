import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';
import 'admin_doc_sheet.dart';

/// Alerts management — sub-tabs for scanner alerts and trade alerts.
class AlertsTab extends ConsumerStatefulWidget {
  const AlertsTab({super.key});
  @override
  ConsumerState<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends ConsumerState<AlertsTab>
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
            tabs: const [Tab(height: 32, text: 'Scanner'), Tab(height: 32, text: 'Trade')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _sub,
            children: const [
              _ScannerAlertsSection(),
              _TradeAlertsSection(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Scanner alerts ---------------------------------------------------------

class _ScannerAlertsSection extends ConsumerStatefulWidget {
  const _ScannerAlertsSection();
  @override
  ConsumerState<_ScannerAlertsSection> createState() => _ScannerAlertsSectionState();
}

class _ScannerAlertsSectionState extends ConsumerState<_ScannerAlertsSection> {
  String? _busyId;

  void _toast(
    String message, {
    bool error = false,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? Colors.white : AppColors.obsidian,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: error ? AppColors.bearish : AppColors.gold,
        duration: Duration(seconds: error ? 6 : 3),
        action: action,
      ),
    );
  }

  Future<void> _promote(String id) async {
    setState(() => _busyId = id);
    try {
      final tradeId = await ref.read(adminRepositoryProvider).promoteScannerToHot(id);
      if (!mounted) return;
      _toast('Promoted to Hot Trade · push fired · $tradeId');
      ref.invalidate(scannerAlertsForAdminProvider);
      ref.invalidate(tradeAlertsForAdminProvider);
    } catch (e) {
      if (!mounted) return;
      _toast('Promote failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _setVisibility(String id, String visibility) async {
    setState(() => _busyId = id);
    final previousVisibility =
        visibility == 'public' ? 'admin_only' : 'public';
    try {
      await ref.read(adminRepositoryProvider).setScannerVisibility(id, visibility);
      if (!mounted) return;
      _toast(
        visibility == 'public'
            ? 'Alert is now visible to customers'
            : 'Alert hidden from customers',
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.obsidian,
          onPressed: () => _setVisibility(id, previousVisibility),
        ),
      );
      ref.invalidate(scannerAlertsForAdminProvider);
    } catch (e) {
      if (!mounted) return;
      _toast('Visibility change failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(scannerAlertsForAdminProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(scannerAlertsForAdminProvider);
        await ref.read(scannerAlertsForAdminProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => ErrorState(
          message: 'Could not load scanner alerts',
          details: e.toString(),
          onRetry: () => ref.invalidate(scannerAlertsForAdminProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No scanner alerts.',
                    style: TextStyle(color: AppColors.textTertiary))),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = list[i];
              final id = (a['id'] ?? '').toString();
              return _AlertRow(
                title: '${a['symbol']} · ${a['kind']}',
                subtitle:
                    '${a['mode']} · ${a['direction']} · grade ${a['grade']} · score ${a['score']}',
                onTap: () => AdminDocSheet.show(
                  context,
                  title: '${a['symbol']} · ${a['kind']}',
                  subtitle: 'scanner_alerts / $id',
                  doc: a,
                ),
                badges: [
                  if (a['visibility'] == 'public') const _Badge(label: 'PUBLIC', color: AppColors.bullish),
                  if (a['visibility'] == 'admin_only') const _Badge(label: 'ADMIN', color: AppColors.warning),
                  if (a['promoted'] == true) const _Badge(label: 'PROMOTED', color: AppColors.gold),
                ],
                actions: [
                  if (a['visibility'] != 'admin_only')
                    _IconButton(
                      icon: Icons.visibility_off_outlined,
                      tooltip: 'Hide from customers',
                      busy: _busyId == id,
                      onTap: () => _setVisibility(id, 'admin_only'),
                    ),
                  if (a['visibility'] == 'admin_only')
                    _IconButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'Make public',
                      busy: _busyId == id,
                      onTap: () => _setVisibility(id, 'public'),
                    ),
                  _IconButton(
                    icon: Icons.local_fire_department_outlined,
                    tooltip: 'Promote to Hot Trade (fires push)',
                    busy: _busyId == id,
                    color: AppColors.gold,
                    onTap: () => _promote(id),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---- Trade alerts -----------------------------------------------------------

class _TradeAlertsSection extends ConsumerStatefulWidget {
  const _TradeAlertsSection();
  @override
  ConsumerState<_TradeAlertsSection> createState() => _TradeAlertsSectionState();
}

class _TradeAlertsSectionState extends ConsumerState<_TradeAlertsSection> {
  String? _busyId;

  /// Section-local gold/red styled snackbar matching the scanner-section
  /// + users-tab pattern. Hides the previous toast so a rapid sequence
  /// of taps doesn't stack indistinguishable notifications.
  void _toast(
    String message, {
    bool error = false,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? Colors.white : AppColors.obsidian,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: error ? AppColors.bearish : AppColors.gold,
        duration: Duration(seconds: error ? 6 : 3),
        action: action,
      ),
    );
  }

  Future<void> _patch(String id, {bool? isHot, String? visibility}) async {
    setState(() => _busyId = id);
    try {
      await ref.read(adminRepositoryProvider).patchTradeAlert(
            id,
            isHot: isHot,
            visibility: visibility,
          );
      ref.invalidate(tradeAlertsForAdminProvider);
      if (!mounted) return;
      // Compose a description that names what just changed, and offer an
      // Undo that flips back the same field. Both isHot and visibility
      // are paired toggles so the inverse is unambiguous.
      String label;
      VoidCallback? undo;
      if (isHot != null) {
        label = isHot
            ? 'Marked as Hot Trade · push fires on next bump'
            : 'Removed from Hot Trades';
        undo = () => _patch(id, isHot: !isHot);
      } else if (visibility != null) {
        label = visibility == 'public'
            ? 'Alert is now visible to customers'
            : 'Alert hidden from customers';
        final inverse =
            visibility == 'public' ? 'admin_only' : 'public';
        undo = () => _patch(id, visibility: inverse);
      } else {
        label = 'Updated';
      }
      _toast(
        label,
        action: undo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                textColor: AppColors.obsidian,
                onPressed: undo,
              ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Update failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(tradeAlertsForAdminProvider);
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.graphite,
          onRefresh: () async {
            ref.invalidate(tradeAlertsForAdminProvider);
            await ref.read(tradeAlertsForAdminProvider.future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
            error: (e, _) => ErrorState(
              message: 'Could not load trade alerts',
              details: e.toString(),
              onRetry: () => ref.invalidate(tradeAlertsForAdminProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    Center(child: Text('No trade alerts. Tap + to compose.',
                        style: TextStyle(color: AppColors.textTertiary))),
                  ],
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = list[i];
                  final id = (a['id'] ?? '').toString();
                  return _AlertRow(
                    title: '${a['symbol']} · ${a['direction']}',
                    subtitle:
                        '${a['kind']} · entry ${a['entry']}${a['target'] != null ? " → ${a['target']}" : ""} · ${a['reason'] ?? ""}',
                    onTap: () => AdminDocSheet.show(
                      context,
                      title: '${a['symbol']} · ${a['direction']}',
                      subtitle: 'trade_alerts / $id',
                      doc: a,
                    ),
                    badges: [
                      if (a['isHot'] == true) const _Badge(label: 'HOT', color: AppColors.bearish),
                      if (a['visibility'] == 'public') const _Badge(label: 'PUBLIC', color: AppColors.bullish),
                      if (a['visibility'] == 'admin_only') const _Badge(label: 'ADMIN', color: AppColors.warning),
                    ],
                    actions: [
                      _IconButton(
                        icon: a['isHot'] == true ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                        tooltip: a['isHot'] == true ? 'Demote' : 'Mark Hot',
                        busy: _busyId == id,
                        color: a['isHot'] == true ? AppColors.bearish : AppColors.gold,
                        onTap: () => _patch(id, isHot: !(a['isHot'] == true)),
                      ),
                      _IconButton(
                        icon: a['visibility'] == 'public'
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        tooltip: a['visibility'] == 'public' ? 'Hide' : 'Make public',
                        busy: _busyId == id,
                        onTap: () => _patch(
                          id,
                          visibility: a['visibility'] == 'public' ? 'admin_only' : 'public',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.obsidian,
            onPressed: () async {
              final created = await showModalBottomSheet<bool>(
                context: context,
                backgroundColor: AppColors.obsidian,
                isScrollControlled: true,
                builder: (_) => const _ComposeTradeAlertSheet(),
              );
              if (created == true) ref.invalidate(tradeAlertsForAdminProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Compose'),
          ),
        ),
      ],
    );
  }
}

// ---- Compose Hot Trade bottom sheet ----------------------------------------

class _ComposeTradeAlertSheet extends ConsumerStatefulWidget {
  const _ComposeTradeAlertSheet();
  @override
  ConsumerState<_ComposeTradeAlertSheet> createState() => _ComposeTradeAlertSheetState();
}

class _ComposeTradeAlertSheetState extends ConsumerState<_ComposeTradeAlertSheet> {
  final _symbol = TextEditingController();
  final _entry = TextEditingController();
  final _target = TextEditingController();
  final _stop = TextEditingController();
  final _reason = TextEditingController();
  String _direction = 'bullish';
  bool _isHot = true;
  bool _submitting = false;

  @override
  void dispose() {
    _symbol.dispose();
    _entry.dispose();
    _target.dispose();
    _stop.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final entry = double.tryParse(_entry.text.trim());
    if (_symbol.text.trim().isEmpty || entry == null || _reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Symbol, entry, and reason are required.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).createTradeAlert({
        'symbol': _symbol.text.trim().toUpperCase(),
        'direction': _direction,
        'entry': entry,
        if (_target.text.trim().isNotEmpty) 'target': double.tryParse(_target.text.trim()),
        if (_stop.text.trim().isNotEmpty) 'stop': double.tryParse(_stop.text.trim()),
        'reason': _reason.text.trim(),
        'isHot': _isHot,
        'visibility': 'public',
        'channel': 'buy',
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _field(String label, TextEditingController c, {bool number = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            filled: true,
            fillColor: AppColors.carbon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.steel),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compose Hot Trade',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 16,
                        fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                const SizedBox(height: 4),
                const Text('Pushed to all devices on save (if Visibility=public).',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                const SizedBox(height: 12),
                _field('Symbol', _symbol),
                Row(children: [
                  Expanded(child: _field('Entry', _entry, number: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('Target', _target, number: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('Stop', _stop, number: true)),
                ]),
                _field('Reason', _reason),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Direction', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Bullish'),
                      selected: _direction == 'bullish',
                      onSelected: (_) => setState(() => _direction = 'bullish'),
                      selectedColor: AppColors.bullishMuted,
                      backgroundColor: AppColors.carbon,
                      labelStyle: TextStyle(
                        color: _direction == 'bullish' ? AppColors.bullish : AppColors.textSecondary,
                        fontSize: 11, fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Bearish'),
                      selected: _direction == 'bearish',
                      onSelected: (_) => setState(() => _direction = 'bearish'),
                      selectedColor: AppColors.bearishMuted,
                      backgroundColor: AppColors.carbon,
                      labelStyle: TextStyle(
                        color: _direction == 'bearish' ? AppColors.bearish : AppColors.textSecondary,
                        fontSize: 11, fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _isHot,
                      activeThumbColor: AppColors.gold,
                      onChanged: (v) => setState(() => _isHot = v),
                    ),
                    const Text('Hot', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.obsidian,
                        ),
                        child: Text(_submitting ? 'Publishing…' : 'Publish'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Shared row + badge components -----------------------------------------

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.actions,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final List<Widget> actions;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                    ...badges.map((b) => Padding(padding: const EdgeInsets.only(left: 4), child: b)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
    final decoration = BoxDecoration(
      color: AppColors.graphite,
      border: Border.all(color: AppColors.steel),
      borderRadius: BorderRadius.circular(12),
    );
    if (onTap == null) {
      return Container(decoration: decoration, child: inner);
    }
    // InkWell wrap so the ripple is bounded by the rounded corners and the
    // PopupMenu / IconButton actions still receive the higher-priority tap.
    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(decoration: decoration, child: inner),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool busy;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: busy
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            )
          : Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
      onPressed: busy ? null : onTap,
    );
  }
}
