import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Scanner ops: kill switches, manual trigger, run history.
class ScannerOpsTab extends ConsumerStatefulWidget {
  const ScannerOpsTab({super.key});

  @override
  ConsumerState<ScannerOpsTab> createState() => _ScannerOpsTabState();
}

class _ScannerOpsTabState extends ConsumerState<ScannerOpsTab> {
  String _mode = 'swing';
  bool _force = false;
  final TextEditingController _tickersCtl = TextEditingController();
  bool _running = false;

  @override
  void dispose() {
    _tickersCtl.dispose();
    super.dispose();
  }

  Future<void> _trigger() async {
    setState(() => _running = true);
    try {
      final raw = _tickersCtl.text.trim();
      final tickers = raw.isEmpty
          ? null
          : raw.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).map((s) => s.toUpperCase()).toList();
      await ref.read(adminRepositoryProvider).triggerScan(
            mode: _mode,
            force: _force,
            tickers: tickers,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan queued: $_mode${_force ? " (forced)" : ""}')),
      );
      // Refresh the runs feed shortly after triggering.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) ref.invalidate(scannerRunsStreamProvider);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trigger failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _setFlag(String key, bool? value) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (key == 'scheduler') {
        await repo.setSchedulerEnabled(value);
      } else if (key == 'push') {
        await repo.setPushScannerPromotes(value);
      }
      ref.invalidate(systemStatusStreamProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flag updated: $key = ${value ?? "default"}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flag update failed: $e'), backgroundColor: AppColors.bearish),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(systemStatusStreamProvider);
    final runs = ref.watch(scannerRunsStreamProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(systemStatusStreamProvider);
        ref.invalidate(scannerRunsStreamProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ---- Kill switches ----
          _SectionCard(
            icon: Icons.power_settings_new,
            title: 'Kill switches',
            child: status.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Loading flags…',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ),
              error: (e, _) => Text('Status unavailable: $e',
                  style: const TextStyle(color: AppColors.bearish, fontSize: 12)),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KillSwitchRow(
                    label: 'Scheduler (cron)',
                    sub: 'Stop all scheduled scans without redeploy',
                    value: s.scheduler.enabled,
                    onChanged: (v) => _setFlag('scheduler', v),
                  ),
                  const SizedBox(height: 6),
                  _KillSwitchRow(
                    label: 'Push for A+ promotes',
                    sub: 'Mute FCM fan-out for high-grade scanner hits',
                    value: s.push.scannerPromotesEnabled,
                    onChanged: (v) => _setFlag('push', v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ---- Manual trigger ----
          _SectionCard(
            icon: Icons.play_arrow,
            title: 'Manual trigger',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ModeDropdown(
                        value: _mode,
                        onChanged: (v) => setState(() => _mode = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _force,
                          onChanged: (v) => setState(() => _force = v),
                          activeThumbColor: AppColors.gold,
                        ),
                        const Text('force',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tickersCtl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'tickers (optional, comma/space separated) e.g. NVDA, TSLA, SPY',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.carbon,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.steel),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : _trigger,
                    icon: _running
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                          )
                        : const Icon(Icons.radar, size: 16),
                    label: Text(_running ? 'Triggering…' : 'Trigger scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.obsidian,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '`force=true` bypasses market-hour guards. The engine still has its own '
                  'budget caps and overlap mutex — won\'t blow your API limits.',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---- Run history ----
          _SectionCard(
            icon: Icons.history,
            title: 'Run history (last 50)',
            child: runs.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
              ),
              error: (e, _) => ErrorState(
                message: 'Could not load run history',
                details: e.toString(),
                onRetry: () => ref.invalidate(scannerRunsStreamProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No runs yet.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                  );
                }
                return Column(
                  children: [
                    for (final r in list) _RunRow(run: r),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w800,
                      fontSize: 13, letterSpacing: 0.4)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _KillSwitchRow extends StatelessWidget {
  const _KillSwitchRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String sub;
  final bool value;
  /// Callback receives null to clear the override (revert to env default).
  final void Function(bool? value) onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.gold,
          onChanged: (v) => onChanged(v),
        ),
        TextButton(
          onPressed: () => onChanged(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textTertiary,
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: const Text('default', style: TextStyle(fontSize: 10, letterSpacing: 0.4)),
        ),
      ],
    );
  }
}

class _ModeDropdown extends StatelessWidget {
  const _ModeDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.steel),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.graphite,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: const Icon(Icons.expand_more, color: AppColors.textTertiary, size: 18),
          items: const [
            DropdownMenuItem(value: 'day', child: Text('Day (intraday)')),
            DropdownMenuItem(value: 'swing', child: Text('Swing (daily)')),
            DropdownMenuItem(value: 'leaps', child: Text('LEAPS (long-term)')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});
  final Map<String, dynamic> run;
  @override
  Widget build(BuildContext context) {
    final mode = (run['mode'] ?? 'swing').toString().toUpperCase();
    final startedAt = run['startedAt']?.toString();
    DateTime? started;
    if (startedAt != null) started = DateTime.tryParse(startedAt);
    final ago = started == null ? '—' : _agoShort(started);
    final dur = run['durationMs'];
    final signals = run['signalsFound'] ?? 0;
    final pub = run['signalsPublished'] ?? 0;
    final promo = run['signalsPromoted'] ?? 0;
    final pushed = run['pushesSent'] ?? 0;
    final api = run['apiCallsUsed'] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(mode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.gold, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 0.7)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ago,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(
                  'signals=$signals  pub=$pub  promo=$promo  push=$pushed  api=$api',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            dur != null ? '${dur}ms' : '—',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

