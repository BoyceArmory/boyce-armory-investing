import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
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

  bool _sendingTestPush = false;
  String? _testPushResult;

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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _SectionHeader('NOTIFICATIONS'),
          _NotificationSection(
            master: _notifMaster,
            scanner: _notifScanner,
            hot: _notifHot,
            adminBuys: _notifAdminBuys,
            premarket: _notifPremarket,
            recap: _notifRecap,
            onMaster: (v) => setState(() => _notifMaster = v),
            onScanner: (v) => setState(() => _notifScanner = v),
            onHot: (v) => setState(() => _notifHot = v),
            onAdminBuys: (v) => setState(() => _notifAdminBuys = v),
            onPremarket: (v) => setState(() => _notifPremarket = v),
            onRecap: (v) => setState(() => _notifRecap = v),
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
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendTestPush() async {
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
  });
  final bool sendingTestPush;
  final String? testPushResult;
  final VoidCallback onSendTestPush;
  final VoidCallback onViewDevices;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: <Widget>[
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
        ],
      ),
    );
  }
}
