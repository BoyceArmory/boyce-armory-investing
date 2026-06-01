import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/admin_providers.dart';

/// Push tab — consolidates every push-related admin action:
///   - Send test push (verify the pipeline works)
///   - @everyone announcement (modal)
///   - View registered devices roster
///   - Counts: total / active / by platform
///
/// Replaces the Settings → Admin scatter where these used to live.
class PushTab extends ConsumerStatefulWidget {
  const PushTab({super.key});
  @override
  ConsumerState<PushTab> createState() => _PushTabState();
}

class _PushTabState extends ConsumerState<PushTab> {
  Map<String, dynamic>? _devices;
  bool _loading = false;
  bool _sending = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  Future<void> _loadDevices() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final r = await repo.listDeviceTokens();
      if (!mounted) return;
      setState(() => _devices = r);
    } catch (_) {
      // silent — leave panel empty on failure
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Flatten the device roster to CSV and copy to clipboard. Use this when
  /// triaging "I'm not getting pushes" — paste into a spreadsheet to filter
  /// by uid, platform, or active status.
  Future<void> _copyRosterCsv() async {
    final rows = (_devices?['rows'] as List?) ?? const <dynamic>[];
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No devices to export.')),
      );
      return;
    }
    final buf = StringBuffer('uid,platform,active,id,updatedAt\n');
    for (final r in rows.whereType<Map<String, dynamic>>()) {
      final uid = (r['uid'] ?? '').toString().replaceAll(',', '');
      final platform = (r['platform'] ?? '').toString().replaceAll(',', '');
      final active = r['active'] == true ? 'true' : 'false';
      final id = (r['id'] ?? '').toString().replaceAll(',', '');
      final updatedAt =
          (r['updatedAt'] ?? '').toString().replaceAll(',', '');
      buf.writeln('$uid,$platform,$active,$id,$updatedAt');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Copied ${rows.length} rows as CSV to clipboard.'),
          backgroundColor: AppColors.bullish),
    );
  }

  Future<void> _sendTest() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _sending = true;
      _testResult = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final r = await repo.sendTestPush();
      final recipients = (r['recipientCount'] as num?)?.toInt() ?? 0;
      final devices = (r['deviceCount'] as num?)?.toInt() ?? 0;
      final fails = (r['failureCount'] as num?)?.toInt() ?? 0;
      final warning = r['warning'] as String?;
      if (!mounted) return;
      setState(() {
        _testResult = warning ??
            'Sent to $recipients/$devices devices. $fails failed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _announce() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AnnouncementDialog(),
    );
    if (result == null) return;
    final force = (result['force'] as bool?) ?? false;
    final title = result['title'] as String;
    final body = result['body'] as String;
    // Confirmation step — announces hit every signed-in customer's lock
    // screen, so we put a hard pause between composing and dispatching.
    // Force mode gets a redder, scarier confirmation since it bypasses
    // user-side mutes AND quiet hours.
    if (!mounted) return;
    final activeCount =
        (_devices?['activeCount'] as num?)?.toInt() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _AnnouncementConfirmDialog(
        title: title,
        body: body,
        force: force,
        reach: activeCount,
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.announce(
        title: title,
        body: body,
        force: force,
      );
      final sent = (res['sent'] as num?)?.toInt() ?? 0;
      final devices = (res['deviceCount'] as num?)?.toInt() ?? 0;
      final warning = res['warning'] as String?;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning ?? 'Announcement sent to $sent/$devices devices.'),
          backgroundColor:
              warning != null ? AppColors.bearish : AppColors.bullish,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Announce failed: $e'),
            backgroundColor: AppColors.bearish),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = (_devices?['total'] as num?)?.toInt() ?? 0;
    final active = (_devices?['activeCount'] as num?)?.toInt() ?? 0;
    final rows = (_devices?['rows'] as List?) ?? const <dynamic>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: <Widget>[
        // ---- Devices summary ----
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.devices_outlined,
                  color: AppColors.gold, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$active / $total devices active',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Only active tokens receive push fan-outs',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh roster',
                onPressed: _loading ? null : _loadDevices,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.gold),
                      )
                    : const Icon(Icons.refresh, color: AppColors.gold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- Actions ----
        _ActionRow(
          icon: Icons.send,
          title: 'Send test push',
          subtitle: _testResult ??
              'Fires a test FCM to every active device. Verifies APNs / FCM / device delivery in one go.',
          busy: _sending,
          onTap: _sendTest,
        ),
        _ActionRow(
          icon: Icons.campaign_outlined,
          title: '@everyone announcement',
          subtitle:
              'Broadcast a custom title + body. Optional force flag to bypass per-user mutes (emergencies only).',
          onTap: _announce,
          danger: true,
        ),
        const SizedBox(height: 18),

        // ---- Device roster ----
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'REGISTERED DEVICES',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            if (rows.isNotEmpty)
              TextButton.icon(
                onPressed: _copyRosterCsv,
                icon: const Icon(Icons.copy_all,
                    size: 14, color: AppColors.gold),
                label: const Text('Copy CSV',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _loading ? 'Loading roster...' : 'No devices registered yet.',
              style: const TextStyle(color: AppColors.textTertiary),
            ),
          )
        else
          for (final r in rows.take(50))
            _DeviceRow(row: r as Map<String, dynamic>),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;
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
                      Text(title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          )),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          )),
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

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final active = row['active'] == true;
    final platform = row['platform']?.toString() ?? 'unknown';
    final id = row['id']?.toString() ?? '';
    final uid = (row['uid']?.toString() ?? '');
    final uidShort = uid.length > 12 ? uid.substring(0, 12) + '...' : uid;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.steel),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.bullish : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$platform · $id',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            uidShort,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Inline announcement dialog (mirror of the Settings version) ---------

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();
  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _force = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.graphite,
      title: const Text('@everyone announcement',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _titleCtrl,
            maxLength: 60,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Title',
              labelStyle: TextStyle(color: AppColors.textTertiary),
            ),
            autofocus: true,
          ),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Body',
              labelStyle: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          SwitchListTile(
            value: _force,
            onChanged: (v) => setState(() => _force = v),
            activeColor: AppColors.bearish,
            contentPadding: EdgeInsets.zero,
            title: const Text('Force delivery (bypass user mutes)',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final t = _titleCtrl.text.trim();
            final b = _bodyCtrl.text.trim();
            if (t.isEmpty || b.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title and body required')),
              );
              return;
            }
            Navigator.of(context).pop(<String, dynamic>{
              'title': t,
              'body': b,
              'force': _force,
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _force ? AppColors.bearish : AppColors.gold,
            foregroundColor: AppColors.obsidian,
          ),
          child: Text(_force ? 'Send (force)' : 'Send'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation dialog — hard pause between composing an announcement and
// actually dispatching it. Force mode gets a redder, more explicit warning
// since it bypasses user mutes AND quiet hours.
// ---------------------------------------------------------------------------

class _AnnouncementConfirmDialog extends StatelessWidget {
  const _AnnouncementConfirmDialog({
    required this.title,
    required this.body,
    required this.force,
    required this.reach,
  });
  final String title;
  final String body;
  final bool force;
  /// Latest active-device count, fed in by the parent so the dialog can
  /// show "Reach: ~N devices". Approximate — actual fan-out also depends
  /// on per-user mutes (regular announce) or nothing (force announce).
  final int reach;

  @override
  Widget build(BuildContext context) {
    final accent = force ? AppColors.bearish : AppColors.gold;
    return AlertDialog(
      backgroundColor: AppColors.graphite,
      title: Row(
        children: <Widget>[
          Icon(
            force ? Icons.warning_amber_rounded : Icons.send_outlined,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            force ? 'Force send to everyone?' : 'Send announcement?',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ---- Preview block: what the lock screen will look like ----
            Container(
              padding:
                  const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.obsidian,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.steel),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'PREVIEW',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ---- Reach summary ----
            Row(
              children: <Widget>[
                Icon(Icons.phonelink_ring,
                    size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Reach: ~$reach active devices',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ---- Force-specific warning ----
            if (force)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bearish.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppColors.bearish.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.error_outline,
                        color: AppColors.bearish, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'FORCE MODE: bypasses every user mute AND quiet hours. '
                        'Use only for emergencies — outage, market early close, true crisis.',
                        style: TextStyle(
                          color: AppColors.bearish,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Skips users who muted announcements or are in quiet hours. '
                'Reach number is approximate — actual delivery is filtered per-user.',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: Icon(force ? Icons.warning_amber_rounded : Icons.send,
              size: 16),
          label: Text(force ? 'Force send now' : 'Send to everyone'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: AppColors.obsidian,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
