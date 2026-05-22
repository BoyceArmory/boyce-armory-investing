import 'package:flutter/material.dart';
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

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.status});
  final SystemStatus status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        _LastFetchedStrip(fetchedAt: status.fetchedAt),
        const SizedBox(height: 10),
        _ServiceCard(service: status.service, scheduler: status.scheduler),
        const SizedBox(height: 12),
        _ScannerCard(scanner: status.scanner),
        const SizedBox(height: 12),
        _ApiCard(api: status.api),
        const SizedBox(height: 12),
        _PushCard(push: status.push),
        const SizedBox(height: 12),
        _DevicesCard(devices: status.devices, firebase: status.firebase),
      ],
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
    final modes = const ['day', 'swing', 'leaps'];
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
