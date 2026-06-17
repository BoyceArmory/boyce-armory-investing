import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../data/system_status_model.dart';
import '../providers/admin_providers.dart';

/// The "what's running" tab — top-level admin health view.
/// Auto-refreshes via systemStatusStreamProvider every 30 seconds.
class StatusTab extends ConsumerWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SystemStatus> async = ref.watch(systemStatusStreamProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.graphite,
      onRefresh: () async {
        ref.invalidate(systemStatusStreamProvider);
        ref.invalidate(backtestHealthProvider);
        await ref.read(systemStatusStreamProvider.future);
      },
      child: async.when(
        loading: () => const _StatusLoading(),
        error: (Object e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: ErrorState(
                message: 'Could not load system status.',
                details: e.toString(),
                onRetry: () => ref.invalidate(systemStatusStreamProvider),
              ),
            ),
          ],
        ),
        data: (SystemStatus s) => _StatusBody(status: s),
      ),
    );
  }
}

class _StatusLoading extends StatelessWidget {
  const _StatusLoading();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: List<Widget>.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.graphite,
              border: Border.all(color: AppColors.steel),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBody extends ConsumerWidget {
  const _StatusBody({required this.status});
  final SystemStatus status;

  // Tab indices on the admin dashboard. Kept in sync with
  // admin_dashboard_screen._specs — if you reorder tabs, update these.
  static const int _scannerTab = 1;
  static const int _pushTab = 4;
  static const int _backtestTab = 5;

  void _jumpTo(WidgetRef ref, int index) {
    ref.read(adminTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter push entries down to true failures or anything with a
    // recorded lastError. Surface them in a dedicated card so admins
    // don't have to scroll the Push card to find what went wrong.
    final recentErrors = [
      for (final e in status.push.queue.recent)
        if (e.status == 'failed' ||
            (e.lastError != null && e.lastError!.isNotEmpty))
          e,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        _LastFetchedStrip(fetchedAt: status.fetchedAt),
        const SizedBox(height: 10),
        if (recentErrors.isNotEmpty) ...[
          _RecentErrorsCard(
            errors: recentErrors,
            onJumpToPushTab: () => _jumpTo(ref, _pushTab),
          ),
          const SizedBox(height: 12),
        ],
        // Service card has no other tab to jump to.
        _ServiceCard(service: status.service, scheduler: status.scheduler),
        const SizedBox(height: 12),
        _TapToTab(
          onTap: () => _jumpTo(ref, _scannerTab),
          child: _ScannerCard(scanner: status.scanner),
        ),
        const SizedBox(height: 12),
        _TapToTab(
          onTap: () => _jumpTo(ref, _backtestTab),
          child: const _BacktestHealthCard(),
        ),
        const SizedBox(height: 12),
        _ApiCard(api: status.api),
        const SizedBox(height: 12),
        _TapToTab(
          onTap: () => _jumpTo(ref, _pushTab),
          child: _PushCard(push: status.push),
        ),
        const SizedBox(height: 12),
        _TapToTab(
          onTap: () => _jumpTo(ref, _pushTab),
          child: _DevicesCard(devices: status.devices, firebase: status.firebase),
        ),
      ],
    );
  }
}

/// Thin tap wrapper for a Status card. Adds a subtle gold "go to tab" affordance
/// without changing the card's visual weight when not hovered. We use a
/// gesture detector instead of wrapping in InkWell so the card's own
/// borderRadius / padding stays the source of truth.
class _TapToTab extends StatelessWidget {
  const _TapToTab({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: child,
          ),
        ),
        Positioned(
          top: 14,
          right: 60,
          child: Icon(
            Icons.arrow_forward,
            size: 10,
            color: AppColors.textTertiary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// -------- recent errors card --------

/// Surfaces the last failed push entries as a top-of-tab alert. Hidden
/// when there are no errors so the Status tab stays calm during normal
/// operation. Each row is tappable — tap jumps to the Push tab where the
/// admin can inspect the full queue, retry, or clear.
class _RecentErrorsCard extends StatelessWidget {
  const _RecentErrorsCard({
    required this.errors,
    required this.onJumpToPushTab,
  });
  final List<PushEntry> errors;
  final VoidCallback onJumpToPushTab;

  @override
  Widget build(BuildContext context) {
    final shown = errors.take(5).toList();
    final extra = errors.length - shown.length;
    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onJumpToPushTab();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.bearish.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppColors.bearish),
                  const SizedBox(width: 6),
                  const Text(
                    'RECENT ERRORS',
                    style: TextStyle(
                      color: AppColors.bearish,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.bearish.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${errors.length}',
                      style: const TextStyle(
                        color: AppColors.bearish,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward,
                      size: 12, color: AppColors.textTertiary),
                ],
              ),
              const SizedBox(height: 8),
              for (final e in shown) _ErrorListEntry(entry: e),
              if (extra > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+$extra more — tap to open Push tab',
                    style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorListEntry extends StatelessWidget {
  const _ErrorListEntry({required this.entry});
  final PushEntry entry;
  @override
  Widget build(BuildContext context) {
    final time = entry.sentAt ?? entry.createdAt;
    // Nested InkWell so tapping a specific error opens the detail sheet
    // INSTEAD of falling through to the parent card's "jump to Push tab"
    // tap. Flutter resolves gestures innermost-first, so the parent
    // InkWell stays inert for the row's hit region.
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.obsidian,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (BuildContext c) => _ErrorDetailSheet(entry: entry),
        );
      },
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(
              color: AppColors.bearish,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title.isEmpty ? '(no title)' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.source} · ${entry.status}${time != null ? " · ${_agoShort(time)}" : ""}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 11),
                ),
                if (entry.lastError != null &&
                    entry.lastError!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      entry.lastError!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.bearish,
                        fontSize: 10.5,
                        height: 1.3,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textTertiary, size: 14),
        ],
      ),
      ),
    );
  }
}

/// Drilldown sheet for a single failed push. The compact list entry
/// truncates lastError to two lines; this sheet shows it full + selectable
/// so the admin can read the entire stack / FCM error code and copy it
/// into a bug ticket. Header surfaces the title + status, then a status
/// block, then the full report table, then raw JSON.
class _ErrorDetailSheet extends StatelessWidget {
  const _ErrorDetailSheet({required this.entry});
  final PushEntry entry;

  Map<String, dynamic> _asMap() => <String, dynamic>{
        'id': entry.id,
        'status': entry.status,
        'source': entry.source,
        'title': entry.title,
        if (entry.symbol != null) 'symbol': entry.symbol,
        if (entry.mode != null) 'mode': entry.mode,
        if (entry.grade != null) 'grade': entry.grade,
        if (entry.recipientCount != null)
          'recipientCount': entry.recipientCount,
        if (entry.createdAt != null)
          'createdAt': entry.createdAt!.toIso8601String(),
        if (entry.sentAt != null) 'sentAt': entry.sentAt!.toIso8601String(),
        if (entry.lastError != null) 'lastError': entry.lastError,
      };

  String _label(String k) {
    switch (k) {
      case 'id':
        return 'Push id';
      case 'status':
        return 'Status';
      case 'source':
        return 'Source';
      case 'title':
        return 'Title';
      case 'symbol':
        return 'Symbol';
      case 'mode':
        return 'Mode';
      case 'grade':
        return 'Grade';
      case 'recipientCount':
        return 'Recipients';
      case 'createdAt':
        return 'Queued at';
      case 'sentAt':
        return 'Sent at';
      case 'lastError':
        return 'Error';
      default:
        return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = _asMap();
    final keys = raw.keys.toList();
    final lastError = entry.lastError ?? '';
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
                    color: AppColors.bearish.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.bearish),
                  ),
                  child: Text(
                    entry.status.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.bearish,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.title.isEmpty ? '(no title)' : entry.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (lastError.isNotEmpty) ...<Widget>[
              const Text(
                'ERROR DETAIL',
                style: TextStyle(
                  color: AppColors.bearish,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bearish.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.bearish.withValues(alpha: 0.55)),
                ),
                child: SelectableText(
                  lastError,
                  style: const TextStyle(
                    color: AppColors.bearish,
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
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
                            width: 100,
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
                              raw[keys[i]].toString(),
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
                        const JsonEncoder.withIndent('  ').convert(raw),
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

// -------- top strip --------

class _LastFetchedStrip extends StatefulWidget {
  const _LastFetchedStrip({required this.fetchedAt});
  final DateTime fetchedAt;
  @override
  State<_LastFetchedStrip> createState() => _LastFetchedStripState();
}

class _LastFetchedStripState extends State<_LastFetchedStrip> {
  late final Stream<int> _tick = Stream.periodic(const Duration(seconds: 1), (i) => i);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _tick,
      builder: (_, __) {
        final ago = _agoShort(widget.fetchedAt);
        return Row(
          children: <Widget>[
            const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              'Last refreshed $ago',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            const Text(
              'auto · 30s',
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

// -------- shared card chrome --------

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.statusColor,
    required this.statusLabel,
    required this.child,
    this.icon,
  });
  final String title;
  final Color statusColor;
  final String statusLabel;
  final Widget child;
  final IconData? icon;

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
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              _StatusDot(color: statusColor, label: statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValRow extends StatelessWidget {
  const _KeyValRow({required this.k, required this.v, this.warn = false});
  final String k;
  final String v;
  final bool warn;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              k,
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: warn ? AppColors.warning : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------- service / scheduler card --------

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.scheduler});
  final ServiceInfo service;
  final SchedulerInfo scheduler;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = scheduler.enabled ? AppColors.bullish : AppColors.bearish;
    return _Card(
      icon: Icons.bolt_outlined,
      title: 'Service / Scheduler',
      statusColor: statusColor,
      statusLabel: scheduler.enabled ? 'LIVE' : 'OFF',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _KeyValRow(k: 'Env', v: service.env),
          _KeyValRow(k: 'Uptime', v: _formatUptime(service.uptimeSec)),
          _KeyValRow(
            k: 'Server time',
            v: service.serverTime?.toIso8601String() ?? '—',
          ),
          _KeyValRow(
            k: 'Scheduler',
            v: scheduler.enabled ? 'enabled' : 'disabled',
            warn: !scheduler.enabled,
          ),
          if (scheduler.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                scheduler.note,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------- scanner card --------

class _ScannerCard extends StatelessWidget {
  const _ScannerCard({required this.scanner});
  final ScannerInfo scanner;

  @override
  Widget build(BuildContext context) {
    const modes = ['day', 'swing', 'leaps'];
    final anyRecent = modes.any((m) {
      final r = scanner.lastRuns[m];
      if (r?.startedAt == null) return false;
      return DateTime.now().difference(r!.startedAt!).inHours < 24;
    });
    return _Card(
      icon: Icons.radar,
      title: 'Scanners',
      statusColor: anyRecent ? AppColors.bullish : AppColors.warning,
      statusLabel: anyRecent ? 'OK' : 'STALE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final m in modes) _ScannerModeRow(mode: m, run: scanner.lastRuns[m]),
          const SizedBox(height: 6),
          Container(height: 1, color: AppColors.steel),
          const SizedBox(height: 6),
          _KeyValRow(k: 'Cooldown table', v: '${scanner.cooldownTableSize} entries'),
        ],
      ),
    );
  }
}

class _ScannerModeRow extends StatelessWidget {
  const _ScannerModeRow({required this.mode, required this.run});
  final String mode;
  final RunSummary? run;

  @override
  Widget build(BuildContext context) {
    final String label = mode.toUpperCase();
    if (run == null || run!.startedAt == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            _ModeTag(label: label),
            const SizedBox(width: 10),
            const Text('no recent runs',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          ],
        ),
      );
    }
    final r = run!;
    final ago = _agoShort(r.startedAt!);
    final dur = r.durationMs != null ? '${r.durationMs}ms' : '—';
    final stale = DateTime.now().difference(r.startedAt!).inHours >= 6;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _ModeTag(label: label),
              const SizedBox(width: 10),
              Text(
                ago,
                style: TextStyle(
                  color: stale ? AppColors.warning : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                dur,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'tickers=${r.tickersScanned}  signals=${r.signalsFound}  '
            'pub=${r.signalsPublished}  promo=${r.signalsPromoted}  '
            'push=${r.pushesSent ?? 0}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

// -------- api card --------

class _ApiCard extends StatelessWidget {
  const _ApiCard({required this.api});
  final ApiInfo api;
  @override
  Widget build(BuildContext context) {
    final warn = api.lifetime.warnings > 0;
    return _Card(
      icon: Icons.swap_horiz_outlined,
      title: 'API budget',
      statusColor: warn ? AppColors.warning : AppColors.bullish,
      statusLabel: warn ? '${api.lifetime.warnings} WARN' : 'CLEAN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _KeyValRow(k: 'Lifetime calls', v: '${api.lifetime.totalCalls}'),
          _KeyValRow(k: 'Current run calls', v: '${api.currentRun.totalCalls}'),
          _KeyValRow(k: 'Rate-limit warnings', v: '${api.lifetime.warnings}', warn: warn),
          if (api.lifetime.byProvider.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('Per-provider lifetime',
                style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 11, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            for (final entry in api.lifetime.byProvider.entries)
              _KeyValRow(k: entry.key, v: '${entry.value}'),
          ],
        ],
      ),
    );
  }
}

// -------- push card --------

class _PushCard extends StatelessWidget {
  const _PushCard({required this.push});
  final PushInfo push;
  @override
  Widget build(BuildContext context) {
    final color = !push.scannerPromotesEnabled
        ? AppColors.textTertiary
        : (push.queue.failedRecent > 0 ? AppColors.warning : AppColors.bullish);
    final label = !push.scannerPromotesEnabled
        ? 'MUTED'
        : (push.queue.failedRecent > 0 ? 'FAILS' : 'OK');
    return _Card(
      icon: Icons.notifications_active_outlined,
      title: 'Push pipeline',
      statusColor: color,
      statusLabel: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _KeyValRow(
            k: 'Scanner promotes',
            v: push.scannerPromotesEnabled ? 'enabled' : 'disabled (kill-switch)',
            warn: !push.scannerPromotesEnabled,
          ),
          _KeyValRow(k: 'Pending', v: '${push.queue.pending}'),
          _KeyValRow(k: 'Sent (recent)', v: '${push.queue.sentRecent}'),
          _KeyValRow(
              k: 'Failed (recent)', v: '${push.queue.failedRecent}',
              warn: push.queue.failedRecent > 0),
          _KeyValRow(
            k: 'Last sent',
            v: push.queue.lastSentAt == null ? '—' : _agoShort(push.queue.lastSentAt!),
          ),
          if (push.queue.recent.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.steel),
            const SizedBox(height: 6),
            const Text('Recent events',
                style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 11, letterSpacing: 0.4)),
            const SizedBox(height: 4),
            for (final p in push.queue.recent) _PushEntryRow(entry: p),
          ],
        ],
      ),
    );
  }
}

class _PushEntryRow extends StatelessWidget {
  const _PushEntryRow({required this.entry});
  final PushEntry entry;
  @override
  Widget build(BuildContext context) {
    final Color c = entry.status == 'sent'
        ? AppColors.bullish
        : entry.status == 'failed'
            ? AppColors.bearish
            : AppColors.warning;
    final time = entry.sentAt ?? entry.createdAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 7, height: 7,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title.isEmpty ? '(no title)' : entry.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.source} · ${entry.status}${entry.recipientCount != null ? " · ${entry.recipientCount} devices" : ""}${time != null ? " · ${_agoShort(time)}" : ""}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
                if (entry.lastError != null && entry.lastError!.isNotEmpty)
                  Text(
                    entry.lastError!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.bearish, fontSize: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------- devices / firebase card --------

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.devices, required this.firebase});
  final DevicesInfo devices;
  final FirebaseInfo firebase;
  @override
  Widget build(BuildContext context) {
    final tokens = devices.activeTokenCount ?? 0;
    final color = firebase.initialized
        ? (tokens > 0 ? AppColors.bullish : AppColors.warning)
        : AppColors.bearish;
    return _Card(
      icon: Icons.devices_other,
      title: 'Devices · Firebase',
      statusColor: color,
      statusLabel:
          !firebase.initialized ? 'OFF' : (tokens > 0 ? 'OK' : 'NO TOKENS'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _KeyValRow(
            k: 'Active device tokens',
            v: devices.activeTokenCount?.toString() ?? '—',
            warn: tokens == 0,
          ),
          _KeyValRow(
            k: 'Firebase Admin',
            v: firebase.initialized ? 'initialized' : 'not initialized',
            warn: !firebase.initialized,
          ),
        ],
      ),
    );
  }
}

// -------- utilities --------

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 5) return 'just now';
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

String _formatUptime(int sec) {
  if (sec < 60) return '${sec}s';
  if (sec < 3600) return '${sec ~/ 60}m ${sec % 60}s';
  if (sec < 86400) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
  final d = sec ~/ 86400;
  final h = (sec % 86400) ~/ 3600;
  return '${d}d ${h}h';
}

// ---------------------------------------------------------------------------
// Backtest health card — measures how the scanner's edge looked over a
// 2y walk-forward backtest. Drives the auto-demote candidate count and the
// "is our edge actually positive" gut-check on Status.
// ---------------------------------------------------------------------------

class _BacktestHealthCard extends ConsumerWidget {
  const _BacktestHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(backtestHealthProvider);
    return async.when(
      loading: () => const _Card(
        icon: Icons.science_outlined,
        title: 'Backtest health',
        statusColor: AppColors.textTertiary,
        statusLabel: '…',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Loading…',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ),
      ),
      error: (e, _) => _Card(
        icon: Icons.science_outlined,
        title: 'Backtest health',
        statusColor: AppColors.bearish,
        statusLabel: 'ERR',
        child: Text(
          e.toString(),
          style: const TextStyle(color: AppColors.bearish, fontSize: 11),
        ),
      ),
      data: (j) {
        final total = (j['totalDetectors'] as num?)?.toInt() ?? 0;
        final profitable = (j['profitable'] as num?)?.toInt() ?? 0;
        final losing = (j['losing'] as num?)?.toInt() ?? 0;
        final neutral = (j['neutral'] as num?)?.toInt() ?? 0;
        final trades = (j['totalTrades'] as num?)?.toInt() ?? 0;
        final topEdge = (j['topEdgePct'] as num?)?.toDouble();
        final topKind = (j['topKind'] as String?) ?? '—';
        final worstEdge = (j['worstEdgePct'] as num?)?.toDouble();
        final worstKind = (j['worstKind'] as String?) ?? '—';
        final lastRunAt = j['lastRunAt'] as String?;
        final demoteCount =
            (j['autoDemoteCandidates'] as num?)?.toInt() ?? 0;

        // Header pill: PROFITABLE if profitable >= losing AND we have data;
        // NEEDS WORK if losing > profitable; NO DATA if no rows.
        Color color;
        String label;
        if (total == 0) {
          color = AppColors.textTertiary;
          label = 'NO DATA';
        } else if (profitable >= losing) {
          color = AppColors.bullish;
          label = 'PROFITABLE';
        } else {
          color = AppColors.warning;
          label = 'MIXED';
        }

        return _Card(
          icon: Icons.science_outlined,
          title: 'Backtest health',
          statusColor: color,
          statusLabel: label,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _BtMetric(
                      value: '$profitable',
                      label: 'profitable',
                      color: AppColors.bullish,
                    ),
                  ),
                  Expanded(
                    child: _BtMetric(
                      value: '$losing',
                      label: 'losing',
                      color: AppColors.bearish,
                    ),
                  ),
                  Expanded(
                    child: _BtMetric(
                      value: '$neutral',
                      label: 'neutral',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: _BtMetric(
                      value: '$total',
                      label: 'total',
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.steel),
              const SizedBox(height: 10),
              _KeyValRow(
                k: 'Top edge',
                v: topEdge == null
                    ? '—'
                    : '${topEdge >= 0 ? "+" : ""}${topEdge.toStringAsFixed(2)}%  ($topKind)',
              ),
              _KeyValRow(
                k: 'Worst edge',
                v: worstEdge == null
                    ? '—'
                    : '${worstEdge >= 0 ? "+" : ""}${worstEdge.toStringAsFixed(2)}%  ($worstKind)',
              ),
              _KeyValRow(k: 'Trades sampled', v: '$trades'),
              _KeyValRow(
                k: 'Last run',
                v: lastRunAt == null
                    ? 'never'
                    : _agoShort(DateTime.tryParse(lastRunAt) ??
                        DateTime.now()),
              ),
              if (demoteCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$demoteCount detector${demoteCount == 1 ? "" : "s"} '
                          'flagged for auto-demote (expectancy ≤ -0.1%, n ≥ 100).',
                          style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BtMetric extends StatelessWidget {
  const _BtMetric({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
