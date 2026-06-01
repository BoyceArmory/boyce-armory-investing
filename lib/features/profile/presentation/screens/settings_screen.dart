import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../../../admin/presentation/providers/admin_providers.dart';

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
  bool _loadingPrefs = true;
  // Advanced prefs
  String _scannerMinGrade = 'all';
  bool _modeDay = true;
  bool _modeSwing = true;
  bool _modeLeaps = true;
  bool _quietEnabled = false;
  int _quietStart = 22;
  int _quietEnd = 6;

  bool _sendingTestPush = false;
  String? _testPushResult;

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
        _scannerMinGrade =
            (prefs['scannerMinGrade'] as String?) ?? 'all';
        _modeDay = (modes['day'] as bool?) ?? true;
        _modeSwing = (modes['swing'] as bool?) ?? true;
        _modeLeaps = (modes['leaps'] as bool?) ?? true;
        _quietEnabled = (quiet['enabled'] as bool?) ?? false;
        _quietStart = (quiet['startHour'] as num?)?.toInt() ?? 22;
        _quietEnd = (quiet['endHour'] as num?)?.toInt() ?? 6;
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
          _SectionHeader('NOTIFICATIONS'),
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
          ] else
          _NotificationSection(
            master: _notifMaster,
            scanner: _notifScanner,
            hot: _notifHot,
            adminBuys: _notifAdminBuys,
            premarket: _notifPremarket,
            recap: _notifRecap,
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
          ),
          const SizedBox(height: 18),

          _SectionHeader('ADVANCED FILTERS'),
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
          const SizedBox(height: 18),

          _SectionHeader('ABOUT'),
          _AboutSection(),
          const SizedBox(height: 18),

          _SectionHeader('RISK DISCLAIMER'),
          const _RiskDisclaimerSection(),
          const SizedBox(height: 18),

          if (isAdmin) ...<Widget>[
            _SectionHeader('ADMIN'),
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
    required this.onMaster,
    required this.onScanner,
    required this.onHot,
    required this.onAdminBuys,
    required this.onPremarket,
    required this.onRecap,
  });

  final bool master;
  final bool scanner;
  final bool hot;
  final bool adminBuys;
  final bool premarket;
  final bool recap;
  final ValueChanged<bool> onMaster;
  final ValueChanged<bool> onScanner;
  final ValueChanged<bool> onHot;
  final ValueChanged<bool> onAdminBuys;
  final ValueChanged<bool> onPremarket;
  final ValueChanged<bool> onRecap;

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
            title: 'ADMIN BUYS chat',
            subtitle: 'Every screenshot Boyce posts in ADMIN BUYS',
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
      activeColor: AppColors.gold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
    );
  }
}

// --------- about ----------------------------------------------------------

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
          ListTile(
            title: const Text('Version',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            trailing: const Text('2.1.0 (14)',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

class _AdminSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
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
            activeColor: AppColors.bearish,
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
