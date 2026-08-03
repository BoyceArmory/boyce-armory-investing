import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';
import 'admin_doc_sheet.dart';

/// Alerts management — scanner alert visibility. The "Trade" sub-tab (Hot
/// Trades manual compose/promote) was removed in Aug 2026 along with the
/// rest of the Hot Trades feature; this is now a single-section view.
class AlertsTab extends ConsumerWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ScannerAlertsSection();
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
                ],
              );
            },
          );
        },
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
