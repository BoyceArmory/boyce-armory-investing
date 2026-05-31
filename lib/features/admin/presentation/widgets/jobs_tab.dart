import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/admin_providers.dart';

/// Jobs tab — every "force this to run right now" admin action in one
/// place. Replaces ~60% of the curl commands you'd otherwise type.
///
/// Each row: title + subtitle + action button. Result snackbar shows the
/// counts the backend returns ("wiped 47 scanner cards, preserved 3 demos").
class JobsTab extends ConsumerStatefulWidget {
  const JobsTab({super.key});
  @override
  ConsumerState<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<JobsTab> {
  String? _busy;

  Future<void> _run(String key, Future<String> Function() fn) async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = key);
    try {
      final msg = await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.bullish),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$key failed: $e'),
            backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: <Widget>[
        const _SectionHeader('Alerts cleanup'),
        _JobRow(
          title: 'Wipe stale alerts',
          subtitle:
              'Mark every scanner/trade alert older than today as invalid. Same as the 9:31 AM ET daily reset, on demand.',
          icon: Icons.cleaning_services_outlined,
          busy: _busy == 'wipe',
          onTap: () => _run('wipe', () async {
            final res = await repo.wipeStale();
            final s = res['scannerInvalidated'] ?? 0;
            final t = res['tradeInvalidated'] ?? 0;
            final d = res['demosPreserved'] ?? 0;
            return 'Wiped $s scanner + $t trade alerts. Preserved $d demos.';
          }),
        ),
        _JobRow(
          title: 'Seed demo alerts',
          subtitle:
              'Insert 3 example Hot Trade cards (SPY, NVDA, QQQ) so the Hot Trades page is never empty for reviewers.',
          icon: Icons.add_box_outlined,
          busy: _busy == 'seed',
          onTap: () => _run('seed', () async {
            final res = await repo.seedDemoAlerts();
            final n = res['seeded'] ?? 0;
            return 'Seeded $n demo alerts.';
          }),
        ),
        _JobRow(
          title: 'Clear demo alerts',
          subtitle:
              'Remove the 3 demo seeds. Use once the live scanner produces enough A+ alerts to keep Hot Trades populated.',
          icon: Icons.delete_outline,
          busy: _busy == 'clear',
          danger: true,
          onTap: () => _run('clear', () async {
            final res = await repo.clearDemoAlerts();
            final n = res['cleared'] ?? 0;
            return 'Cleared $n demo alerts.';
          }),
        ),
        const SizedBox(height: 18),
        const _SectionHeader('Performance / Recap'),
        _JobRow(
          title: 'Run daily recap',
          subtitle:
              'Force the 5 PM ET recap aggregation. Use after a bulk import or manual close so Desk Performance reflects the new numbers immediately.',
          icon: Icons.summarize_outlined,
          busy: _busy == 'recap',
          onTap: () => _run('recap', () async {
            await repo.triggerDailyRecap();
            return 'Daily recap recomputed.';
          }),
        ),
        const SizedBox(height: 18),
        const _SectionHeader('Backtest'),
        _JobRow(
          title: 'Run backtest now',
          subtitle:
              'Replays 2 years of daily candles through the scanner. ~30s. Refreshes per-detector measured edge in setup_stats.',
          icon: Icons.analytics_outlined,
          busy: _busy == 'backtest',
          onTap: () => _run('backtest', () async {
            final res = await repo.runBacktest();
            final groups = res['groups'] ?? 0;
            final total = res['total'] ?? 0;
            return 'Backtest done: $groups detector kinds, $total trades.';
          }),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.busy,
    required this.onTap,
    this.danger = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color accent = danger ? AppColors.bearish : AppColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.graphite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.steel),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: <Widget>[
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: accent),
                      )
                    : Icon(Icons.chevron_right, color: accent, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
