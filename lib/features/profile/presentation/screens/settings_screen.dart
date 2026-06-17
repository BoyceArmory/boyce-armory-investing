import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../../core/services/position_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../../../shared/widgets/watchlist_manager_sheet.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

/// Settings screen. Notification toggles, About, Risk Disclaimer, and
/// admin-only diagnostics (test push, device token roster). Access from
/// Profile → Settings.
///
/// Notification toggles persist locally as state for now; backend filtering
/// by per-user preference is a 2.1.1 follow-up. The "Send test push" admin
/// button fires through every active device token via the new
/// /api/admin/push/test endpoint and reports back delivery counts.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifMaster = true;
  bool _notifScanner = true;
  bool _notifHot = true;
  bool _notifAdminBuys = true;
  bool _notifPremarket = true;
  bool _notifRecap = true;
  // OPT-IN: default false so unconfigured users don't see scalp alerts.
  bool _notifScalp = false;
  bool _loadingPrefs = true;
  // Advanced prefs
  String _scannerMinGrade = 'all';
  bool _modeDay = true;
  bool _modeSwing = true;
  bool _modeLeaps = true;
  bool _quietEnabled = false;
  int _quietStart = 22;
  int _quietEnd = 6;
  // Global snooze. Stored as ISO timestamp; null/empty/past = inactive.
  DateTime? _snoozeUntil;

  bool _sendingTestPush = false;
  String? _testPushResult;
  // Customer-facing self-test diagnostic (separate from the admin
  // broadcast tester so the two buttons can show different result lines).
  bool _sendingSelfTestPush = false;
  String? _selfTestPushResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Future<void> _loadPrefs() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final prefs = await repo.fetchMyNotificationPrefs();
      if (!mounted) return;
      final modes = (prefs['scannerModes'] as Map?) ?? const {};
      final quiet = (prefs['quietHours'] as Map?) ?? const {};
      setState(() {
        _notifMaster = (prefs['master'] as bool?) ?? true;
        _notifScanner = (prefs['scanner'] as bool?) ?? true;
        _notifHot = (prefs['hot'] as bool?) ?? true;
        _notifAdminBuys = (prefs['adminBuys'] as bool?) ?? true;
        _notifPremarket = (prefs['premarket'] as bool?) ?? true;
        _notifRecap = (prefs['recap'] as bool?) ?? true;
        // Scalp is the only OPT-IN channel — default OFF when missing
        // from the server response. User must explicitly toggle on.
        _notifScalp = (prefs['scalp'] as bool?) ?? false;
        _scannerMinGrade =
            (prefs['scannerMinGrade'] as String?) ?? 'all';
        _modeDay = (modes['day'] as bool?) ?? true;
        _modeSwing = (modes['swing'] as bool?) ?? true;
        _modeLeaps = (modes['leaps'] as bool?) ?? true;
        _quietEnabled = (quiet['enabled'] as bool?) ?? false;
        _quietStart = (quiet['startHour'] as num?)?.toInt() ?? 22;
        _quietEnd = (quiet['endHour'] as num?)?.toInt() ?? 6;
        final rawSnooze = (prefs['snoozeUntil'] as String?) ?? '';
        final parsed = rawSnooze.isEmpty ? null : DateTime.tryParse(rawSnooze);
        _snoozeUntil =
            (parsed != null && parsed.isAfter(DateTime.now())) ? parsed : null;
        _loadingPrefs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _savePref(String key, bool value) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateMyNotificationPrefs({key: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  /// Save an advanced (non-boolean) preference. Single key/value patch —
  /// backend merges. Used by the min-grade enum, per-mode toggles, and
  /// the quiet-hours sub-fields.
  Future<void> _saveAdvanced(Map<String, dynamic> patch) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateMyNotificationPrefsAdvanced(patch);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  /// Set or clear the global snooze. Pass null to clear (writes ""), or
  /// a future DateTime to suppress all pushes until that time. UTC is
  /// used for the wire format; the user sees their local time in the UI.
  Future<void> _setSnooze(DateTime? until) async {
    final iso = until == null ? '' : until.toUtc().toIso8601String();
    setState(() => _snoozeUntil =
        (until != null && until.isAfter(DateTime.now())) ? until : null);
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateMyNotificationPrefsAdvanced({'snoozeUntil': iso});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(until == null
                ? 'Snooze cleared'
                : 'Snoozed until ${_fmtLocalTime(until)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snooze failed: $e')),
        );
      }
    }
  }

  /// Wipe every notification + chat-mute preference back to factory
  /// defaults. Two-tap confirm via AlertDialog. After success we reload
  /// the prefs so the UI snaps to the cleared state without waiting for
  /// the next manual refresh.
  Future<void> _resetAllPrefs() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: const Text(
          'Reset notification settings?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Every channel toggle, advanced filter, quiet-hours window, snooze, and per-room chat mute will be restored to defaults. Your account, sizing prefs, and chat messages are untouched.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bearish,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.resetMyNotificationPrefs();
      final user = ref.read(currentFirebaseUserProvider);
      if (user != null) {
        await ref.read(chatPrefsServiceProvider).clearAllMutes(user.uid);
      }
      if (!mounted) return;
      // Re-fetch so the toggles snap to defaults visually.
      await _loadPrefs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings reset to defaults')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $e')),
        );
      }
    }
  }

  String _fmtLocalTime(DateTime t) {
    final local = t.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$h:$m';
    return '${local.month}/${local.day} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        title: const Text('SETTINGS',
            style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6)),
        iconTheme: const IconThemeData(color: AppColors.gold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RoutePaths.profile),
        ),
      ),
      body: ResponsiveContainer(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          const _SectionHeader('NOTIFICATIONS'),
          if (_loadingPrefs) ...<Widget>[
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.gold),
                ),
              ),
            ),
          ] else ...[
          _SnoozeCard(
            snoozeUntil: _snoozeUntil,
            onSnooze: _setSnooze,
            onClear: () => _setSnooze(null),
          ),
          const SizedBox(height: 18),
          _NotificationSection(
            master: _notifMaster,
            scanner: _notifScanner,
            hot: _notifHot,
            adminBuys: _notifAdminBuys,
            premarket: _notifPremarket,
            recap: _notifRecap,
            scalp: _notifScalp,
            onMaster: (v) {
              setState(() => _notifMaster = v);
              _savePref('master', v);
            },
            onScanner: (v) {
              setState(() => _notifScanner = v);
              _savePref('scanner', v);
            },
            onHot: (v) {
              setState(() => _notifHot = v);
              _savePref('hot', v);
            },
            onAdminBuys: (v) {
              setState(() => _notifAdminBuys = v);
              _savePref('adminBuys', v);
            },
            onPremarket: (v) {
              setState(() => _notifPremarket = v);
              _savePref('premarket', v);
            },
            onRecap: (v) {
              setState(() => _notifRecap = v);
              _savePref('recap', v);
            },
            onScalp: (v) {
              setState(() => _notifScalp = v);
              _savePref('scalp', v);
            },
          ),
          ],
          const SizedBox(height: 18),

          const _SectionHeader('ADVANCED FILTERS'),
          _AdvancedNotificationsSection(
            scannerOn: _notifScanner && _notifMaster,
            minGrade: _scannerMinGrade,
            modeDay: _modeDay,
            modeSwing: _modeSwing,
            modeLeaps: _modeLeaps,
            quietEnabled: _quietEnabled,
            quietStart: _quietStart,
            quietEnd: _quietEnd,
            onMinGrade: (v) {
              setState(() => _scannerMinGrade = v);
              _saveAdvanced({'scannerMinGrade': v});
            },
            onMode: (mode, v) {
              setState(() {
                if (mode == 'day') _modeDay = v;
                if (mode == 'swing') _modeSwing = v;
                if (mode == 'leaps') _modeLeaps = v;
              });
              _saveAdvanced({
                'scannerModes': {mode: v}
              });
            },
            onQuietEnabled: (v) {
              setState(() => _quietEnabled = v);
              _saveAdvanced({
                'quietHours': {'enabled': v}
              });
            },
            onQuietStart: (h) {
              setState(() => _quietStart = h);
              _saveAdvanced({
                'quietHours': {'startHour': h}
              });
            },
            onQuietEnd: (h) {
              setState(() => _quietEnd = h);
              _saveAdvanced({
                'quietHours': {'endHour': h}
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _SelfTestPushButton(
                busy: _sendingSelfTestPush,
                resultLine: _selfTestPushResult,
                onTap: _sendSelfTestPush,
              ),
              const Spacer(),
              _ResetPrefsButton(onReset: _resetAllPrefs),
            ],
          ),
          const SizedBox(height: 18),

          const _SectionHeader('ACCOUNT'),
          const _AccountInfoSection(),
          const SizedBox(height: 18),

          const _SectionHeader('POSITION SIZING'),
          _PositionSizingSection(),
          const SizedBox(height: 18),

          const _SectionHeader('MY DATA'),
          _MyDataSection(),
          const SizedBox(height: 18),

          const _SectionHeader('HELP'),
          const _HelpSection(),
          const SizedBox(height: 18),

          const _SectionHeader('ABOUT'),
          _AboutSection(),
          const SizedBox(height: 18),

          const _SectionHeader('RISK DISCLAIMER'),
          const _RiskDisclaimerSection(),
          const SizedBox(height: 18),

          if (isAdmin) ...<Widget>[
            const _SectionHeader('ADMIN'),
            _AdminSection(
              sendingTestPush: _sendingTestPush,
              testPushResult: _testPushResult,
              onSendTestPush: _sendTestPush,
              onViewDevices: _viewDevices,
              onAnnounce: _openAnnounceDialog,
            ),
          ],
        ],
      ),
      ),
    );
  }

  /// Self-test diagnostic — sends a push to ONLY the current user's
  /// active tokens, respecting their full preference stack. The result
  /// line tells the user what the queue would do for a real push right
  /// now (delivered, snoozed, in quiet hours, master off, etc.) so they
  /// can verify their settings end-to-end without waiting for a real
  /// alert to fire.
  Future<void> _sendSelfTestPush() async {
    if (_sendingSelfTestPush) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _sendingSelfTestPush = true;
      _selfTestPushResult = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.sendMyTestPush();
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final deviceCount = (result['deviceCount'] as num?)?.toInt() ?? 0;
      final suppressedBy = result['suppressedBy'] as String?;
      final warning = result['warning'] as String?;
      String line;
      if (warning != null) {
        line = warning;
      } else if (suppressedBy != null) {
        switch (suppressedBy) {
          case 'master_off':
            line = 'Suppressed: notifications master toggle is OFF.';
            break;
          case 'scanner_off':
            line = 'Suppressed: scanner channel toggle is OFF.';
            break;
          case 'snooze':
            final until = result['snoozeUntil'] as String? ?? '';
            line = 'Suppressed: snooze active${until.isNotEmpty ? ' until ${until.substring(0, 16)}' : ''}.';
            break;
          case 'quiet_hours':
            line = 'Suppressed: quiet hours active.';
            break;
          default:
            line = 'Suppressed: $suppressedBy.';
        }
      } else {
        line = 'Sent to $sent of $deviceCount device(s). Check your lock screen.';
      }
      setState(() => _selfTestPushResult = line);
    } catch (e) {
      setState(() => _selfTestPushResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _sendingSelfTestPush = false);
    }
  }

  Future<void> _sendTestPush() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _sendingTestPush = true;
      _testPushResult = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.sendTestPush();
      final recipientCount = (result['recipientCount'] as num?)?.toInt() ?? 0;
      final failureCount = (result['failureCount'] as num?)?.toInt() ?? 0;
      final deviceCount = (result['deviceCount'] as num?)?.toInt() ?? 0;
      final warning = result['warning'] as String?;
      setState(() {
        _testPushResult = warning != null
            ? '⚠ $warning'
            : 'Sent to $recipientCount/$deviceCount devices. $failureCount failed.';
      });
    } catch (e) {
      setState(() => _testPushResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _sendingTestPush = false);
    }
  }

  Future<void> _openAnnounceDialog() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AnnouncementDialog(),
    );
    if (result == null) return;
    final force = (result['force'] as bool?) ?? false;
    final title = result['title'] as String;
    final body = result['body'] as String;
    // Confirmation step. Fetches the live device count so the admin
    // sees the actual reach before pulling the trigger.
    int reach = 0;
    try {
      final repo0 = ref.read(adminRepositoryProvider);
      final devs = await repo0.listDeviceTokens();
      reach = (devs['activeCount'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Best-effort — fall through with reach=0; the confirm still works.
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _AnnounceConfirmSheet(
        title: title,
        body: body,
        force: force,
        reach: reach,
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.heavyImpact();
    try {
      final repo = ref.read(adminRepositoryProvider);
      final res = await repo.announce(
        title: title,
        body: body,
        force: force,
      );
      if (!mounted) return;
      final sent = (res['sent'] as num?)?.toInt() ?? 0;
      final devices = (res['deviceCount'] as num?)?.toInt() ?? 0;
      final warning = res['warning'] as String?;
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
        SnackBar(content: Text('Announce failed: $e')),
      );
    }
  }

  Future<void> _viewDevices() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final result = await repo.listDeviceTokens();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.graphite,
          title: const Text('Registered devices',
              style: TextStyle(color: AppColors.textPrimary)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Text(
                _formatDeviceList(result),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                    fontSize: 11),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to list devices: $e')),
        );
      }
    }
  }

  String _formatDeviceList(Map<String, dynamic> result) {
    final total = result['total'] ?? 0;
    final active = result['activeCount'] ?? 0;
    final rows = (result['rows'] as List?) ?? const <dynamic>[];
    final sb = StringBuffer();
    sb.writeln('Total: $total  |  Active: $active');
    sb.writeln('');
    for (final r in rows.take(50)) {
      final row = r as Map<String, dynamic>;
      sb.writeln(
        '${row['active'] == true ? "ON " : "OFF"}  '
        '${row['platform']?.toString().padRight(8)}  '
        '${row['id']?.toString().padRight(16)}  '
        '${row['uid']?.toString().substring(0, 8) ?? ""}',
      );
    }
    return sb.toString();
  }
}

// --------- shared widgets -------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      child: child,
    );
  }
}

// --------- notification toggles -------------------------------------------

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.master,
    required this.scanner,
    required this.hot,
    required this.adminBuys,
    required this.premarket,
    required this.recap,
    required this.scalp,
    required this.onMaster,
    required this.onScanner,
    required this.onHot,
    required this.onAdminBuys,
    required this.onPremarket,
    required this.onRecap,
    required this.onScalp,
  });

  final bool master;
  final bool scanner;
  final bool hot;
  final bool adminBuys;
  final bool premarket;
  final bool recap;
  final bool scalp;
  final ValueChanged<bool> onMaster;
  final ValueChanged<bool> onScanner;
  final ValueChanged<bool> onHot;
  final ValueChanged<bool> onAdminBuys;
  final ValueChanged<bool> onPremarket;
  final ValueChanged<bool> onRecap;
  final ValueChanged<bool> onScalp;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
          ListTile(
            title: const Text('Notification inbox',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text(
              'See every push the desk has sent recently',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            leading: const Icon(Icons.inbox_outlined,
                color: AppColors.gold, size: 20),
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textTertiary),
            onTap: () => context.go(RoutePaths.notifications),
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'All notifications',
            subtitle: 'Master switch for every push channel',
            value: master,
            onChanged: onMaster,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'Scanner alerts',
            subtitle: 'A+ scanner promotes that fire push',
            value: scanner && master,
            onChanged: master ? onScanner : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'Hot Trades',
            subtitle: 'Auto-merged + manually published Hot Trade alerts',
            value: hot && master,
            onChanged: master ? onHot : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'Chat broadcasts + @mentions',
            subtitle:
                'ADMIN BUYS screenshots, @everyone announcements, and @user mentions',
            value: adminBuys && master,
            onChanged: master ? onAdminBuys : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'Premarket watchlist',
            subtitle: '9:25 AM ET morning watchlist push',
            value: premarket && master,
            onChanged: master ? onPremarket : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'Daily recap',
            subtitle: '5 PM ET wrap-up: today\'s wins/losses',
            value: recap && master,
            onChanged: master ? onRecap : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            // Scalp is opt-in: subtitle calls it out explicitly so users
            // don't enable it by accident. Default is OFF on server side
            // too — even if the master toggle flips on, scalp stays off
            // until the user opts in here.
            title: 'Scalp alerts · OPT-IN',
            subtitle:
                '0DTE 5-min scalps on SPY/QQQ/mega-caps. High frequency, fast decay — only enable if you\'re actively trading the screen.',
            value: scalp && master,
            onChanged: master ? onScalp : null,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.gold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
    );
  }
}

// --------- about ----------------------------------------------------------

/// Per-user data tiles — watchlist today, room to grow (saved searches,
/// custom universes, etc.) without crowding the Notifications or About
/// sections. Lives between Advanced Filters and About on Settings.
class _MyDataSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int count = ref.watch(watchlistProvider).length;
    return _Card(
      child: ListTile(
        title: const Text('My watchlist',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        subtitle: Text(
          count == 0
              ? 'Tap the star on any alert card to start watching a ticker'
              : '$count ticker${count == 1 ? '' : 's'} · manage or clear',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.star, color: AppColors.gold, size: 22),
          ],
        ),
        onTap: () => WatchlistManagerSheet.show(context),
      ),
    );
  }
}

/// Two-input form for storing the user's account size + max risk per
/// trade. Drives the inline sizing chip on every alert card so users
/// see "3 contracts · $450 · 1.5% risk" without re-doing the math each
/// alert. Edits save optimistically through SizingPrefsController.
class _PositionSizingSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PositionSizingSection> createState() =>
      _PositionSizingSectionState();
}

class _PositionSizingSectionState
    extends ConsumerState<_PositionSizingSection> {
  late TextEditingController _account;
  late TextEditingController _risk;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _account = TextEditingController();
    _risk = TextEditingController();
  }

  @override
  void dispose() {
    _account.dispose();
    _risk.dispose();
    super.dispose();
  }

  void _seedFromState(SizingPrefs p) {
    if (_seeded) return;
    // Provider bootstraps async — first build sees an empty SizingPrefs
    // before the server responds. Skip seeding until real values arrive
    // so the fields don't lock in as blanks and ignore the server load.
    if (p.accountSize == null && p.maxRiskPct == null) return;
    if (p.accountSize != null) {
      _account.text = p.accountSize!.toStringAsFixed(0);
    }
    if (p.maxRiskPct != null) {
      _risk.text = p.maxRiskPct!.toString();
    }
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sizingPrefsProvider);
    final ctl = ref.read(sizingPrefsProvider.notifier);
    _seedFromState(prefs);

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We never know your real broker balance — these numbers stay on your account and only drive the in-app sizing chip.',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Account size',
                    prefix: r'$',
                    controller: _account,
                    onSubmit: (v) {
                      final n = double.tryParse(v.replaceAll(',', ''));
                      if (n != null && n > 0) {
                        ctl.setAccountSize(n);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    label: 'Max risk per trade',
                    suffix: '%',
                    controller: _risk,
                    onSubmit: (v) {
                      final n = double.tryParse(v);
                      if (n != null && n > 0 && n <= 50) {
                        ctl.setMaxRiskPct(n);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Conventional: 0.5% conservative · 1-2% typical · 5% aggressive.',
              style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    required this.onSubmit,
    this.prefix,
    this.suffix,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            isDense: true,
            prefixText: prefix,
            suffixText: suffix,
            prefixStyle: const TextStyle(color: AppColors.textSecondary),
            suffixStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.carbon,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.steel),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
          onSubmitted: onSubmit,
          onEditingComplete: () => onSubmit(controller.text),
        ),
      ],
    );
  }
}

/// Quick-link card surfacing the most-asked-about features as taps to
/// existing lessons, plus a "Report a bug" mailto with diagnostic info
/// (app version + uid) pre-filled in the subject so support tickets
/// arrive identifiable. Sits between MY DATA and ABOUT so it's close to
/// where users land when they hit "I'm stuck on something".
class _HelpSection extends ConsumerWidget {
  const _HelpSection();

  void _openLesson(BuildContext context, String section, String lesson) {
    context.go(RoutePaths.lessonsLessonFor(section, lesson));
  }

  Future<void> _emailBug(WidgetRef ref) async {
    String version = '';
    try {
      final info = await ref.read(appInfoProvider.future);
      version = '${info.version} (${info.build})';
    } catch (_) {}
    final uid = ref.read(currentFirebaseUserProvider)?.uid ?? '';
    final subject = Uri.encodeComponent(
      'App bug · v$version · uid:${uid.isEmpty ? "(not signed in)" : uid}',
    );
    final body = Uri.encodeComponent(
      'Describe the bug here. What were you doing? What did you expect? What happened instead?\n\n'
      '---\n(Do not edit below — helps us diagnose)\n'
      'Version: $version\nUID: $uid\n',
    );
    final mailto = Uri.parse(
      'mailto:support@boycearmory.com?subject=$subject&body=$body',
    );
    await launchUrl(mailto);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        children: <Widget>[
          _HelpTile(
            icon: Icons.menu_book_outlined,
            title: 'How to read a trade card',
            subtitle:
                'Every part of the Hot Trade + Scanner card, decoded top to bottom.',
            onTap: () => _openLesson(context, 'foundations', 'how-to-read-alerts'),
          ),
          const Divider(color: AppColors.steel, height: 1),
          _HelpTile(
            icon: Icons.forum_outlined,
            title: 'Using the chat',
            subtitle: '@mentions, mute per room, unread badges, search.',
            onTap: () => _openLesson(context, 'execution', 'using-the-chat'),
          ),
          const Divider(color: AppColors.steel, height: 1),
          _HelpTile(
            icon: Icons.bedtime_outlined,
            title: 'How Snooze works',
            subtitle: 'Silence everything for a window without rewriting your prefs.',
            onTap: () => _openLesson(context, 'execution', 'using-snooze'),
          ),
          const Divider(color: AppColors.steel, height: 1),
          _HelpTile(
            icon: Icons.new_releases_outlined,
            title: "What's new",
            subtitle:
                'Version history — every feature shipped, by release.',
            onTap: () => context.go(RoutePaths.changelog),
          ),
          const Divider(color: AppColors.steel, height: 1),
          _HelpTile(
            icon: Icons.bug_report_outlined,
            title: 'Report a bug',
            subtitle:
                'Email support with your app version + uid attached automatically.',
            onTap: () => _emailBug(ref),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

class _AboutSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        children: <Widget>[
          ListTile(
            title: const Text('Version',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            // Reads version + build at runtime from the platform via
            // package_info_plus. Replaces the prior hardcoded literal
            // that drifted from pubspec on every release.
            trailing: ref.watch(appInfoProvider).when(
                  loading: () => const Text('—',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  error: (_, __) => const Text('—',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  data: (({String version, String build}) info) => Text(
                      '${info.version} (${info.build})',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('Contact support',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text('Tap to email us with feedback or a question',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.mail_outline,
                color: AppColors.textTertiary),
            onTap: () => launchUrl(
              Uri.parse('mailto:support@boycearmory.com?subject=App%20feedback'),
            ),
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('Rate Boyce Armory',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text('Tap to leave a review on the App Store',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.star_outline,
                color: AppColors.textTertiary),
            onTap: () => launchUrl(
              Uri.parse(
                  'https://apps.apple.com/app/boyce-armory/id0000000000?action=write-review'),
            ),
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('Terms of service',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            trailing: const Icon(Icons.open_in_new,
                color: AppColors.textTertiary, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://boycearmory.com/terms'),
            ),
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('Privacy policy',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            trailing: const Icon(Icons.open_in_new,
                color: AppColors.textTertiary, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://boycearmory.com/privacy'),
            ),
          ),
        ],
      ),
    );
  }
}

// --------- risk disclaimer ------------------------------------------------

class _RiskDisclaimerSection extends StatelessWidget {
  const _RiskDisclaimerSection();
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Educational content only — not financial advice.',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Boyce Armory publishes options trading setups and education for informational purposes only. Nothing in this app is personalized financial advice, a recommendation to buy or sell any security, or a guarantee of profit. Options trading is high-risk and can result in the total loss of capital — including more than you invest in certain strategies.\n\n'
              'You alone are responsible for every trade you place. Past performance, scanner backtest stats, and the desk track record shown in this app are not a promise of future results. Before trading options you should read the Characteristics and Risks of Standardized Options (the "options disclosure document") published by the OCC, and consult a licensed financial professional if you are unsure whether options are appropriate for your situation.\n\n'
              'By using Boyce Armory you confirm that you have read, understood, and agreed to our Terms of Service.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(
                  'https://www.theocc.com/company-information/documents-and-archives/options-disclosure-document')),
              icon: const Icon(Icons.open_in_new,
                  color: AppColors.gold, size: 16),
              label: const Text(
                'Read OCC options disclosure document',
                style: TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------- admin -----------------------------------------------------------

class _AdminSection extends ConsumerWidget {
  const _AdminSection({
    required this.sendingTestPush,
    required this.testPushResult,
    required this.onSendTestPush,
    required this.onViewDevices,
    required this.onAnnounce,
  });
  final bool sendingTestPush;
  final String? testPushResult;
  final VoidCallback onSendTestPush;
  final VoidCallback onViewDevices;
  final VoidCallback onAnnounce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unreadEvents = ref.watch(adminEventsUnreadCountProvider);
    return _Card(
      child: Column(
        children: <Widget>[
          ListTile(
            title: const Text('Notifications inbox',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text(
                'New signups, support tickets, role/tier changes',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unreadEvents > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Text('$unreadEvents',
                        style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.inbox_outlined,
                    color: AppColors.gold, size: 22),
              ],
            ),
            onTap: () => context.go(RoutePaths.adminNotifications),
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('@everyone announcement',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text(
                'Fire a broadcast push to every active device. Use sparingly — this is the "needs to reach everyone right now" channel.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.campaign_outlined,
                color: AppColors.gold, size: 22),
            onTap: onAnnounce,
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('Send test push',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: Text(
              testPushResult ??
                  'Fires a test FCM to every active device token. Verifies the full push pipeline (token → FCM → APNs → device).',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: sendingTestPush
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  )
                : const Icon(Icons.send, color: AppColors.gold, size: 22),
            onTap: sendingTestPush ? null : onSendTestPush,
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('View registered devices',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text(
                'Roster of device tokens (no token values shown). If your uid is missing here, push will never reach you.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.devices_outlined,
                color: AppColors.gold, size: 22),
            onTap: onViewDevices,
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('Open Admin Dashboard',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text(
                'Scanner kill switch, force scan, alerts moderation, audit log',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing:
                const Icon(Icons.dashboard_outlined, color: AppColors.gold),
            onTap: () => context.go(RoutePaths.adminDashboard),
          ),
          const Divider(color: AppColors.steel, height: 1),
          ListTile(
            title: const Text('View backtest results',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            subtitle: const Text(
                'Per-detector measured edge (win rate, expectancy, regime breakdown) from the backtest engine',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            trailing:
                const Icon(Icons.analytics_outlined, color: AppColors.gold),
            onTap: () => context.go(RoutePaths.backtest),
          ),
        ],
      ),
    );
  }
}

// ---- @everyone announcement dialog ---------------------------------------

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _titleCtrl,
            maxLength: 60,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Title',
              labelStyle: TextStyle(color: AppColors.textTertiary),
              hintText: 'e.g. Market closed early today',
              hintStyle: TextStyle(color: AppColors.textTertiary),
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
              hintText: 'Short message shown on the lock screen',
              hintStyle: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _force,
            onChanged: (v) => setState(() => _force = v),
            activeThumbColor: AppColors.bearish,
            contentPadding: EdgeInsets.zero,
            title: const Text('Force delivery (bypass user mutes)',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Use only for emergencies. Reaches users who have muted announcements.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.send, size: 16),
          label: Text(_force ? 'Send (force)' : 'Send'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _force ? AppColors.bearish : AppColors.gold,
            foregroundColor: AppColors.obsidian,
          ),
          onPressed: () {
            final title = _titleCtrl.text.trim();
            final body = _bodyCtrl.text.trim();
            if (title.isEmpty || body.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title and body required')),
              );
              return;
            }
            Navigator.of(context).pop(<String, dynamic>{
              'title': title,
              'body': body,
              'force': _force,
            });
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Advanced notification filters — min grade, per-mode scanner toggles,
// quiet-hours window. Lives below the main on/off switches in Settings.
// All controls write through to /api/users/me/notifications via the same
// updateMyNotificationPrefsAdvanced flow.
// ---------------------------------------------------------------------------

/// Global snooze card. Surfaces quick-action chips for the most common
/// "leave me alone for a bit" cases (1h, 8h, until 8am tomorrow) and a
/// live countdown chip when snooze is active. The whole card flashes a
/// gold border + status row when armed so users don't accidentally
/// forget they silenced everything.
class _SnoozeCard extends StatelessWidget {
  const _SnoozeCard({
    required this.snoozeUntil,
    required this.onSnooze,
    required this.onClear,
  });
  final DateTime? snoozeUntil;
  final ValueChanged<DateTime> onSnooze;
  final VoidCallback onClear;

  /// Compute "08:00 tomorrow" in the user's local timezone. If it's
  /// currently past 8am, this is literally tomorrow morning; if it's
  /// before 8am today, the result is later this same morning.
  DateTime _tomorrowMorning() {
    final now = DateTime.now();
    final today8 = DateTime(now.year, now.month, now.day, 8);
    if (today8.isAfter(now)) return today8;
    return today8.add(const Duration(days: 1));
  }

  String _remaining(DateTime until) {
    final d = until.difference(DateTime.now());
    if (d.isNegative) return 'expired';
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h ${m}m left';
    }
    return '${d.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    final armed = snoozeUntil != null;
    final color = armed ? AppColors.gold : AppColors.steel;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: armed
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: armed ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                armed ? Icons.bedtime : Icons.bedtime_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Snooze all notifications',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (armed)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.bearish,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            armed
                ? 'Silenced until ${_fmtLocal(snoozeUntil!)} · ${_remaining(snoozeUntil!)}'
                : 'Pick a window — every push (scanner, hot, chat, premarket, recap) is suppressed until it expires.',
            style: TextStyle(
              color: armed ? AppColors.gold : AppColors.textSecondary,
              fontWeight: armed ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Chip(
                label: '1 hour',
                onTap: () =>
                    onSnooze(DateTime.now().add(const Duration(hours: 1))),
              ),
              _Chip(
                label: '8 hours',
                onTap: () =>
                    onSnooze(DateTime.now().add(const Duration(hours: 8))),
              ),
              _Chip(
                label: 'Until 8am',
                onTap: () => onSnooze(_tomorrowMorning()),
              ),
              _Chip(
                label: 'Custom…',
                onTap: () => _pickCustom(context, onSnooze),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Open a custom-duration picker. We use a quick-pick chip grid (15 min
  /// up through "Market close" + "Tomorrow open") rather than a heavy
  /// material time picker — the surface area is small and the values
  /// people actually want are predictable. "Market close" computes the
  /// next 16:00 ET; "Tomorrow open" computes the next 09:30 ET.
  static Future<void> _pickCustom(
    BuildContext context,
    ValueChanged<DateTime> onSnooze,
  ) async {
    DateTime now() => DateTime.now();
    DateTime nextEastern(int h, int m) {
      final n = now();
      // App is iPhone-only US-market — local time is close enough to ET
      // for snooze purposes. A full tz-aware computation would need
      // intl/timezone packages; not worth the binary cost here.
      final target = DateTime(n.year, n.month, n.day, h, m);
      return target.isAfter(n) ? target : target.add(const Duration(days: 1));
    }

    final options = <_DurationOption>[
      const _DurationOption('15 min', Duration(minutes: 15)),
      const _DurationOption('30 min', Duration(minutes: 30)),
      const _DurationOption('2 hours', Duration(hours: 2)),
      const _DurationOption('4 hours', Duration(hours: 4)),
      const _DurationOption('12 hours', Duration(hours: 12)),
      const _DurationOption('24 hours', Duration(hours: 24)),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.obsidian,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (BuildContext c) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'CUSTOM SNOOZE',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pick a window. Snooze is per-account, so it syncs across every device you\'re signed in on.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final o in options)
                      _Chip(
                        label: o.label,
                        onTap: () {
                          Navigator.pop(c);
                          onSnooze(now().add(o.dur));
                        },
                      ),
                    _Chip(
                      label: 'Until market close (16:00)',
                      onTap: () {
                        Navigator.pop(c);
                        onSnooze(nextEastern(16, 0));
                      },
                    ),
                    _Chip(
                      label: 'Until tomorrow open (09:30)',
                      onTap: () {
                        Navigator.pop(c);
                        onSnooze(nextEastern(9, 30));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmtLocal(DateTime t) {
    final local = t.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    if (sameDay) return '$h:$m';
    return '${local.month}/${local.day} $h:$m';
  }
}

/// Read-only profile block with creation date, last sign-in, tier badge,
/// and a collapsed UID for support requests. Designed to feel
/// professional without becoming a full account editor — the avatar
/// + display name editor live elsewhere in the Profile flow.
class _AccountInfoSection extends ConsumerStatefulWidget {
  const _AccountInfoSection();
  @override
  ConsumerState<_AccountInfoSection> createState() =>
      _AccountInfoSectionState();
}

class _AccountInfoSectionState extends ConsumerState<_AccountInfoSection> {
  bool _showUid = false;

  String _fmt(DateTime? t) {
    if (t == null) return '—';
    final local = t.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final fbUser = ref.watch(currentFirebaseUserProvider);
    final appUser = ref.watch(appUserProvider).asData?.value;
    if (fbUser == null) {
      return const _InfoCard(rows: <_KV>[
        _KV('Status', 'Not signed in'),
      ]);
    }
    final created = fbUser.metadata.creationTime;
    final lastSeen = fbUser.metadata.lastSignInTime;
    final tierLabel = appUser?.isAdmin == true ? 'Admin' : 'Member';
    final email = fbUser.email ?? appUser?.email ?? '—';
    final displayName = appUser?.displayName?.trim().isNotEmpty == true
        ? appUser!.displayName!
        : (fbUser.displayName?.trim().isNotEmpty == true
            ? fbUser.displayName!.trim()
            : '—');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Text(
                  tierLabel.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Member since', value: _fmt(created)),
          const SizedBox(height: 6),
          _InfoRow(label: 'Last sign-in', value: _fmt(lastSeen)),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _showUid = !_showUid),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    _showUid ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Support ID',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  if (_showUid)
                    IconButton(
                      tooltip: 'Copy uid',
                      icon: const Icon(Icons.copy,
                          size: 14, color: AppColors.textTertiary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fbUser.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UID copied')),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                ],
              ),
            ),
          ),
          if (_showUid)
            SelectableText(
              fbUser.uid,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Tiny wrapper used by the "not signed in" fallback only.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_KV> rows;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _InfoRow(label: r.k, value: r.v),
                ))
            .toList(),
      ),
    );
  }
}

class _KV {
  const _KV(this.k, this.v);
  final String k;
  final String v;
}

/// Customer-facing "Send test push to me" trigger. Pairs with the reset
/// button on the same row. When [resultLine] is non-null we render a
/// thin caption below the button so the diagnostic stays anchored to
/// its trigger. Busy state collapses the button to a spinner.
class _SelfTestPushButton extends StatelessWidget {
  const _SelfTestPushButton({
    required this.busy,
    required this.resultLine,
    required this.onTap,
  });
  final bool busy;
  final String? resultLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextButton.icon(
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                )
              : const Icon(Icons.send, size: 16, color: AppColors.gold),
          label: const Text(
            'Send test push to me',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (resultLine != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: SizedBox(
              width: 240,
              child: Text(
                resultLine!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Destructive secondary-style button that nukes every push pref + chat
/// mute. Lives at the bottom of the Notifications block; the dialog
/// confirm lives on the parent state class.
class _ResetPrefsButton extends StatelessWidget {
  const _ResetPrefsButton({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onReset,
        icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.bearish),
        label: const Text(
          'Reset notification settings',
          style: TextStyle(
            color: AppColors.bearish,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _DurationOption {
  const _DurationOption(this.label, this.dur);
  final String label;
  final Duration dur;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _AdvancedNotificationsSection extends StatelessWidget {
  const _AdvancedNotificationsSection({
    required this.scannerOn,
    required this.minGrade,
    required this.modeDay,
    required this.modeSwing,
    required this.modeLeaps,
    required this.quietEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.onMinGrade,
    required this.onMode,
    required this.onQuietEnabled,
    required this.onQuietStart,
    required this.onQuietEnd,
  });

  /// Disables the grade + mode subgroup when the master Scanner switch is off.
  final bool scannerOn;
  final String minGrade;
  final bool modeDay;
  final bool modeSwing;
  final bool modeLeaps;
  final bool quietEnabled;
  final int quietStart;
  final int quietEnd;
  final ValueChanged<String> onMinGrade;
  final void Function(String mode, bool value) onMode;
  final ValueChanged<bool> onQuietEnabled;
  final ValueChanged<int> onQuietStart;
  final ValueChanged<int> onQuietEnd;

  static const List<String> _grades = <String>['all', 'B', 'B+', 'A', 'A+'];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ---- Min grade ------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'SCANNER MIN GRADE',
              style: TextStyle(
                color: scannerOn ? AppColors.gold : AppColors.textTertiary,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Drop pushes for any scanner alert below this grade.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _grades.map((g) {
                final isActive = g == minGrade;
                return InkWell(
                  onTap: scannerOn ? () => onMinGrade(g) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.gold.withValues(alpha: 0.16)
                          : AppColors.obsidian,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? AppColors.gold.withValues(alpha: 0.6)
                            : AppColors.steel,
                      ),
                    ),
                    child: Text(
                      g == 'all' ? 'All' : g,
                      style: TextStyle(
                        color: scannerOn
                            ? (isActive
                                ? AppColors.gold
                                : AppColors.textSecondary)
                            : AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const Divider(color: AppColors.steel, height: 1),
          // ---- Per-mode toggles -----------------------------------------
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'SCANNER MODES',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Which scanner modes can push to your phone.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          _Tile(
            title: 'Day setups',
            subtitle: 'Intraday signals (1m-15m timeframe)',
            value: modeDay && scannerOn,
            onChanged: scannerOn ? (v) => onMode('day', v) : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'Swing setups',
            subtitle: 'Multi-day positions (daily timeframe)',
            value: modeSwing && scannerOn,
            onChanged: scannerOn ? (v) => onMode('swing', v) : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          _Tile(
            title: 'LEAPS setups',
            subtitle: 'Long-dated weekly thesis trades',
            value: modeLeaps && scannerOn,
            onChanged: scannerOn ? (v) => onMode('leaps', v) : null,
          ),
          const Divider(color: AppColors.steel, height: 1),
          // ---- Quiet hours ----------------------------------------------
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'QUIET HOURS',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Suppress pushes during these hours (your local ET).',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          _Tile(
            title: 'Enable quiet hours',
            subtitle: quietEnabled
                ? 'Active ${_fmtHour(quietStart)} → ${_fmtHour(quietEnd)}'
                : 'Currently off — all approved pushes ring through',
            value: quietEnabled,
            onChanged: onQuietEnabled,
          ),
          if (quietEnabled) ...<Widget>[
            const Divider(color: AppColors.steel, height: 1),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _HourPicker(
                      label: 'Start',
                      hour: quietStart,
                      onChanged: onQuietStart,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HourPicker(
                      label: 'End',
                      hour: quietEnd,
                      onChanged: onQuietEnd,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.label,
    required this.hour,
    required this.onChanged,
  });
  final String label;
  final int hour;
  final ValueChanged<int> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.graphite,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onChanged(picked.hour);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.obsidian,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.steel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtHour(hour),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtHour(int h) {
  if (h == 0) return '12:00 AM';
  if (h < 12) return '${h.toString().padLeft(2, "0")}:00 AM';
  if (h == 12) return '12:00 PM';
  return '${(h - 12).toString().padLeft(2, "0")}:00 PM';
}

// ---------------------------------------------------------------------------
// Confirmation dialog for the Settings → Admin announce shortcut. Mirrors
// the one in push_tab.dart so the second entry point also has a hard pause
// + preview + force-mode warning before dispatching.
// ---------------------------------------------------------------------------

class _AnnounceConfirmSheet extends StatelessWidget {
  const _AnnounceConfirmSheet({
    required this.title,
    required this.body,
    required this.force,
    required this.reach,
  });
  final String title;
  final String body;
  final bool force;
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
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
            Row(
              children: <Widget>[
                Icon(Icons.phonelink_ring, size: 14, color: accent),
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
                'Reach is approximate — actual delivery is filtered per-user.',
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
