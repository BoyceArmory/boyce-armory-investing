import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Rich per-user detail bottom sheet. Tap any row in the Users tab to
/// open this — shows everything an admin would want to know about a
/// signed-up user in one place:
///
///   • Identity: email, displayName, uid, photoURL (all copyable)
///   • Status pills: role, tier, disabled, NEW (last 24h)
///   • Signup info: createdAt + relative time, last notifiedAt
///   • Push readiness: active device tokens count
///   • Engagement: watchlist count + first 12 tickers, last 5 alert actions
///   • Prefs summary: master/scanner/hot/premarket toggles + min-grade +
///                    sizingPrefs (accountSize, maxRiskPct)
///
/// All data lives behind a single round-trip to /api/admin/users/:uid/detail
/// so opening the sheet is one fast network call.
class UserDetailSheet extends ConsumerStatefulWidget {
  const UserDetailSheet({super.key, required this.uid});
  final String uid;

  static Future<void> show(BuildContext context, String uid) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.graphite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => UserDetailSheet(uid: uid),
    );
  }

  @override
  ConsumerState<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends ConsumerState<UserDetailSheet> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await ref
          .read(adminRepositoryProvider)
          .fetchUserDetail(widget.uid);
      if (!mounted) return;
      setState(() {
        _data = j;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.steel,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(Icons.person_outline,
                    color: AppColors.gold, size: 18),
                SizedBox(width: 8),
                Text(
                  'User detail',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.steel, height: 1),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold))
                : _error != null
                    ? ErrorState(
                        message: 'Could not load user detail',
                        details: _error,
                        onRetry: _load,
                      )
                    : _DetailBody(
                        data: _data!,
                        scrollCtrl: scrollCtrl,
                        onCopy: _copy,
                      ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.scrollCtrl,
    required this.onCopy,
  });
  final Map<String, dynamic> data;
  final ScrollController scrollCtrl;
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final uid = (user['id'] ?? user['uid'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final displayName = (user['displayName'] ?? '').toString();
    final role = (user['role'] ?? 'customer').toString();
    final tier = (user['tier'] ?? 'free').toString();
    final disabled = user['disabled'] == true;
    final createdAt = (user['createdAt'] ?? '').toString();
    final notifiedAt = (user['notifiedAt'] ?? '').toString();
    final activeTokens = (stats['activeTokens'] as num?)?.toInt() ?? 0;
    final watchlistCount =
        (stats['watchlistCount'] as num?)?.toInt() ?? 0;
    final watchlistPreview =
        ((stats['watchlistPreview'] as List?) ?? const [])
            .whereType<String>()
            .toList();
    final recentActions =
        ((stats['recentActions'] as List?) ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
    final notifPrefs =
        (user['notificationPrefs'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final sizingPrefs =
        (user['sizingPrefs'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---- Identity row -------------------------------------------
        Text(
          displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email : 'no name'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (email.isNotEmpty && email != displayName)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _CopyableRow(
              label: 'email',
              value: email,
              onTap: () => onCopy('email', email),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _CopyableRow(
            label: 'uid',
            value: uid,
            onTap: () => onCopy('uid', uid),
          ),
        ),
        const SizedBox(height: 10),
        // ---- Status pills -------------------------------------------
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Pill(
              text: role.toUpperCase(),
              color:
                  role == 'admin' ? AppColors.gold : AppColors.textSecondary,
            ),
            _Pill(
              text: tier.toUpperCase(),
              color:
                  tier == 'premium' ? AppColors.bullish : AppColors.textTertiary,
            ),
            if (disabled)
              const _Pill(text: 'DISABLED', color: AppColors.bearish),
            if (_isWithinLast24h(createdAt))
              const _Pill(text: 'NEW', color: AppColors.gold),
          ],
        ),
        const SizedBox(height: 16),
        // ---- Stats grid ---------------------------------------------
        const _SectionHeader(title: 'Activity'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.devices,
                label: 'Active tokens',
                value: '$activeTokens',
                hint: activeTokens == 0
                    ? 'No push will land'
                    : 'Push pipeline ready',
                color: activeTokens == 0
                    ? AppColors.bearish
                    : AppColors.bullish,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.star,
                label: 'Watchlist',
                value: '$watchlistCount',
                hint: watchlistCount == 0 ? 'Empty' : 'Tickers watched',
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.event,
                label: 'Signed up',
                value: _timeAgo(createdAt),
                hint: _absDate(createdAt),
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.notifications,
                label: 'Last notify',
                value: notifiedAt.isEmpty ? '—' : _timeAgo(notifiedAt),
                hint:
                    notifiedAt.isEmpty ? 'Never' : _absDate(notifiedAt),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        if (watchlistPreview.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Watchlist preview'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in watchlistPreview)
                _TickerChip(symbol: t),
              if (watchlistCount > watchlistPreview.length)
                _Pill(
                  text: '+${watchlistCount - watchlistPreview.length} more',
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ],

        if (recentActions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionHeader(title: 'Recent actions'),
          const SizedBox(height: 8),
          for (final a in recentActions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ActionRow(action: a),
            ),
        ],

        const SizedBox(height: 16),
        const _SectionHeader(title: 'Notification prefs'),
        const SizedBox(height: 8),
        _PrefSummary(prefs: notifPrefs),

        const SizedBox(height: 16),
        const _SectionHeader(title: 'Sizing'),
        const SizedBox(height: 8),
        _SizingSummary(prefs: sizingPrefs),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy,
                size: 12, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.steel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  const _TickerChip({required this.symbol});
  final String symbol;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Text(
        symbol,
        style: const TextStyle(
          color: AppColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});
  final Map<String, dynamic> action;
  @override
  Widget build(BuildContext context) {
    final kind = (action['action'] ?? action['kind'] ?? '').toString();
    final alertId = (action['alertId'] ?? '').toString();
    final at = (action['at'] ?? action['createdAt'] ?? '').toString();
    final (icon, color) = _kindMeta(kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.steel),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            kind.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          if (alertId.isNotEmpty)
            Expanded(
              child: Text(
                alertId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            )
          else
            const Spacer(),
          Text(
            _timeAgo(at),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

(IconData, Color) _kindMeta(String kind) {
  switch (kind) {
    case 'took':
      return (Icons.check, AppColors.bullish);
    case 'watching':
      return (Icons.visibility_outlined, AppColors.gold);
    case 'pass':
      return (Icons.close, AppColors.bearish);
    default:
      return (Icons.bolt, AppColors.textSecondary);
  }
}

class _PrefSummary extends StatelessWidget {
  const _PrefSummary({required this.prefs});
  final Map<String, dynamic> prefs;
  @override
  Widget build(BuildContext context) {
    final master = prefs['master'] != false;
    final scanner = prefs['scanner'] != false;
    final hot = prefs['hot'] != false;
    final premarket = prefs['premarket'] != false;
    final recap = prefs['recap'] != false;
    final minGrade = (prefs['scannerMinGrade'] ?? 'all').toString();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Pill(
          text: master ? 'MASTER ON' : 'MASTER OFF',
          color: master ? AppColors.bullish : AppColors.bearish,
        ),
        _Pill(text: 'SCANNER ${scanner ? "ON" : "OFF"}',
            color: scanner ? AppColors.textSecondary : AppColors.bearish),
        _Pill(text: 'HOT ${hot ? "ON" : "OFF"}',
            color: hot ? AppColors.textSecondary : AppColors.bearish),
        _Pill(text: 'PREMKT ${premarket ? "ON" : "OFF"}',
            color: premarket ? AppColors.textSecondary : AppColors.bearish),
        _Pill(text: 'RECAP ${recap ? "ON" : "OFF"}',
            color: recap ? AppColors.textSecondary : AppColors.bearish),
        _Pill(text: 'MIN ${minGrade.toUpperCase()}',
            color: AppColors.gold),
      ],
    );
  }
}

class _SizingSummary extends StatelessWidget {
  const _SizingSummary({required this.prefs});
  final Map<String, dynamic> prefs;
  @override
  Widget build(BuildContext context) {
    final acct = (prefs['accountSize'] as num?)?.toDouble();
    final risk = (prefs['maxRiskPct'] as num?)?.toDouble();
    if (acct == null && risk == null) {
      return const Text(
        'Not configured — sizing chips on alerts show the "Set sizing" CTA for this user.',
        style: TextStyle(
            color: AppColors.textTertiary, fontSize: 12, height: 1.4),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (acct != null)
          _Pill(
            text: 'ACCT \$${acct.toStringAsFixed(0)}',
            color: AppColors.gold,
          ),
        if (risk != null)
          _Pill(
            text: 'RISK ${risk.toStringAsFixed(2)}%',
            color: AppColors.gold,
          ),
      ],
    );
  }
}

// --- helpers ---------------------------------------------------------

bool _isWithinLast24h(String iso) {
  if (iso.isEmpty) return false;
  final t = DateTime.tryParse(iso);
  if (t == null) return false;
  return DateTime.now().difference(t.toLocal()).inHours < 24;
}

String _timeAgo(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '—';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}

String _absDate(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final l = t.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}
