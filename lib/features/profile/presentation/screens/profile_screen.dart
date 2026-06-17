import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/services/engagement_service.dart';
import '../../../performance/presentation/providers/performance_providers.dart';
import '../../data/snooze_service.dart';
import '../providers/profile_providers.dart';
import '../widgets/avatar_uploader.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppUser?> userAsync = ref.watch(appUserProvider);
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: userAsync.when(
        loading: () => const SafeArea(child: LoadingIndicator()),
        error: (Object e, _) => SafeArea(
          child: Center(
            child: Text(
              'Failed to load profile.\n$e',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ),
        ),
        data: (AppUser? u) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const SectionHeader(eyebrow: 'Account', title: 'Profile'),
              const SizedBox(height: 16),

              // ---- Identity card ----
              FadeSlideIn(child: _IdentityCard(user: u)),
              const SizedBox(height: 14),

              // ---- Notifications status — surfaces snooze + master so
              // users don't have to dig into Settings just to check why
              // they're not getting alerts. Tap = jump to Settings.
              const _NotifStatusRow(),
              const SizedBox(height: 14),

              // ---- At-a-glance dashboard — watchlist size, lifetime
              // trades, 7-day P&L. Each tile is tappable to the source
              // screen so the row doubles as nav. Stats stay live via
              // their underlying providers.
              const _QuickStatsRow(),
              const SizedBox(height: 14),

              // ---- Account actions ----
              const _SectionLabel(text: 'Account'),
              _ActionCard(children: [
                _ActionRow(
                  icon: Icons.badge_outlined,
                  label: 'Display name',
                  value: u?.displayName ?? '—',
                  onTap: () => _editDisplayName(context, ref, u?.displayName),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.alternate_email,
                  label: 'Nickname',
                  value: _nicknameOf(u) ?? 'Not set',
                  onTap: () => _editNickname(context, ref, _nicknameOf(u)),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: u?.email ?? '—',
                  onTap: () => _changeEmail(context, ref, u?.email),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.lock_outline,
                  label: 'Password',
                  value: 'Change password',
                  onTap: () => _changePassword(context, ref),
                ),
              ]),

              const SizedBox(height: 14),

              // ---- Quick links ----
              const _SectionLabel(text: 'Quick links'),
              _ActionCard(children: [
                _ActionRow(
                  icon: Icons.show_chart,
                  label: 'Active & Closed Trades',
                  onTap: () => context.go(RoutePaths.trades),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.insights_outlined,
                  label: 'Performance',
                  onTap: () => context.go(RoutePaths.performance),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.school_outlined,
                  label: 'Lessons',
                  onTap: () => context.go(RoutePaths.lessons),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.notifications_active_outlined,
                  label: 'Notifications',
                  onTap: () => context.go(RoutePaths.notifications),
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => context.go(RoutePaths.settings),
                ),
              ]),

              const SizedBox(height: 14),

              // ---- Help ----
              const _SectionLabel(text: 'Help'),
              _ActionCard(children: [
                _ActionRow(
                  icon: Icons.support_agent,
                  label: 'Send a trouble ticket',
                  onTap: () => context.push(RoutePaths.supportTicket),
                ),
              ]),

              const SizedBox(height: 22),

              // ---- Danger zone ----
              const _SectionLabel(text: 'Danger zone', color: AppColors.bearish),
              _ActionCard(children: [
                _ActionRow(
                  icon: Icons.logout,
                  label: 'Sign out',
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    if (context.mounted) context.go(RoutePaths.signIn);
                  },
                ),
                const _Divider(),
                _ActionRow(
                  icon: Icons.delete_forever_outlined,
                  label: 'Delete account',
                  value: 'Permanent',
                  destructive: true,
                  onTap: () => _deleteAccount(context, ref),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String? _nicknameOf(AppUser? u) {
    // AppUser doesn't have a typed nickname yet — read it off the raw doc via
    // the appUserProvider extra field if it's there. For now we display
    // displayName as a fallback in the row.
    final dynamic v = (u as dynamic);
    try {
      return v?.nickname as String?;
    } catch (_) {
      return null;
    }
  }

  // ---- Edit display name --------------------------------------------------

  Future<void> _editDisplayName(BuildContext context, WidgetRef ref, String? current) async {
    final ctl = TextEditingController(text: current ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: 'Display name',
        hint: 'Your real name',
        controller: ctl,
        submitLabel: 'Save',
      ),
    );
    if (newName == null || newName.trim().isEmpty) return;
    try {
      await ref.read(profileRepositoryProvider).updateDisplayName(newName.trim());
      ref.invalidate(appUserProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.bearish),
        );
      }
    }
  }

  Future<void> _editNickname(BuildContext context, WidgetRef ref, String? current) async {
    final ctl = TextEditingController(text: current ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: 'Nickname',
        hint: 'Shown in chat & public lists',
        controller: ctl,
        submitLabel: 'Save',
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    try {
      await ref.read(profileRepositoryProvider).updateNickname(v.trim());
      ref.invalidate(appUserProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nickname updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.bearish),
        );
      }
    }
  }

  // ---- Change email -------------------------------------------------------

  Future<void> _changeEmail(BuildContext context, WidgetRef ref, String? current) async {
    final reauth = await _reauthPrompt(context, ref,
        message: 'Confirm your password to change email.');
    if (reauth != true) return;
    if (!context.mounted) return;
    final ctl = TextEditingController(text: current ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: 'New email',
        hint: 'name@example.com',
        controller: ctl,
        submitLabel: 'Send verification',
        keyboardType: TextInputType.emailAddress,
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    final res = await ref.read(authServiceProvider).updateEmail(v.trim());
    if (!context.mounted) return;
    if (res is Success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification sent to ${v.trim()}. Click the link to confirm.')),
      );
    } else if (res is Failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.bearish),
      );
    }
  }

  // ---- Change password ----------------------------------------------------

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final reauth = await _reauthPrompt(context, ref,
        message: 'Confirm your current password.');
    if (reauth != true) return;
    if (!context.mounted) return;
    final newPw = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: 'New password',
        hint: 'At least 8 characters',
        controller: newPw,
        submitLabel: 'Change',
        obscure: true,
      ),
    );
    if (v == null || v.length < 8) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use at least 8 characters.')),
        );
      }
      return;
    }
    final res = await ref.read(authServiceProvider).updatePassword(v);
    if (!context.mounted) return;
    if (res is Success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } else if (res is Failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.bearish),
      );
    }
  }

  // ---- Delete account -----------------------------------------------------

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: const Text('Delete your account?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This permanently deletes your account, sign-out from all devices, '
          'and stops all push notifications. Your historical activity is '
          'anonymized but not removed. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bearish,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final reauth = await _reauthPrompt(context, ref,
        message: 'Confirm your password to delete your account.');
    if (reauth != true) return;

    try {
      // 1. Server cascade — deactivates tokens, anonymizes user doc, deletes
      //    Firebase Auth user, writes audit log.
      await ref.read(profileRepositoryProvider).deleteAccountCascade();
      // 2. Local Firebase Auth user is already gone server-side; explicit
      //    signOut clears any cached credential.
      await ref.read(authServiceProvider).signOut();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted. Goodbye for now.')),
      );
      context.go(RoutePaths.signIn);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.bearish),
      );
    }
  }

  /// Prompts for the current password and re-authenticates with Firebase.
  /// Returns true on success.
  Future<bool?> _reauthPrompt(BuildContext context, WidgetRef ref, {required String message}) async {
    final ctl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(
        title: 'Confirm password',
        hint: message,
        controller: ctl,
        submitLabel: 'Confirm',
        obscure: true,
      ),
    );
    if (pw == null || pw.isEmpty) return false;
    final res = await ref.read(authServiceProvider).reauthenticate(pw);
    if (!context.mounted) return false;
    if (res is Success) return true;
    if (res is Failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.bearish),
      );
    }
    return false;
  }
}

// ---- Identity card ----------------------------------------------------------

class _IdentityCard extends ConsumerWidget {
  const _IdentityCard({required this.user});
  final AppUser? user;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AvatarUploader(
            photoUrl: user?.photoUrl,
            initials: _initials(user),
            onUploaded: () => ref.invalidate(appUserProvider),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.displayName ?? 'Boyce Armory member',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    (user?.isAdmin ?? false) ? 'ADMIN' : 'MEMBER',
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(AppUser? u) {
    final String name = (u?.displayName ?? u?.email ?? 'BA').trim();
    if (name.isEmpty) return 'BA';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ---- Section label / action card / row -------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
            color: color ?? AppColors.textTertiary,
            fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final Color accent = destructive ? AppColors.bearish : AppColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: destructive ? AppColors.bearish : AppColors.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  if (value != null && value!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(value!,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Three-tile dashboard row showing watchlist size, lifetime closed
/// trades, and 7-day P&L. Each tile is tappable. Stats stay live via
/// the underlying providers — no manual refresh required.
class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final tradesAsync = ref.watch(userClosedTradesProvider);
    final closedCount = tradesAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    // 7-day P&L percent — sum of pnlPct over trades whose closedAt is
    // within the last 7 days. Cheap O(N) pass; trade lists are small.
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final weekPnl = tradesAsync.maybeWhen(
      data: (list) {
        double sum = 0;
        for (final t in list) {
          if (t.closedAt.isAfter(cutoff)) sum += t.pnlPct;
        }
        return sum;
      },
      orElse: () => 0.0,
    );
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            icon: Icons.star,
            label: 'Watchlist',
            value: '${watchlist.length}',
            tone: AppColors.gold,
            onTap: () => context.go(RoutePaths.scanner),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.show_chart,
            label: 'Lifetime trades',
            value: '$closedCount',
            tone: AppColors.gold,
            onTap: () => context.go(RoutePaths.performance),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: weekPnl >= 0 ? Icons.trending_up : Icons.trending_down,
            label: '7-day P&L',
            value:
                '${weekPnl >= 0 ? "+" : ""}${weekPnl.toStringAsFixed(1)}%',
            tone: weekPnl >= 0 ? AppColors.bullish : AppColors.bearish,
            onTap: () => context.go(RoutePaths.performance),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.steel),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: tone, size: 16),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surfaces master toggle + snooze state on Profile so users don't have
/// to open Settings to check why pushes are quiet. Two colored chips +
/// a tap target that routes to Settings → Notifications.
class _NotifStatusRow extends ConsumerWidget {
  const _NotifStatusRow();

  String _untilLabel(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterOn =
        ref.watch(masterNotifProvider).maybeWhen(data: (v) => v, orElse: () => true);
    final snooze =
        ref.watch(activeSnoozeProvider).maybeWhen(data: (v) => v, orElse: () => null);

    // Decide the headline. Snooze is the loudest signal so it wins.
    final bool muted = !masterOn || snooze != null;
    final Color tone = muted ? AppColors.gold : AppColors.bullish;
    String headline;
    String detail;
    if (snooze != null) {
      headline = 'Snoozed until ${_untilLabel(snooze)}';
      detail = 'All pushes suppressed until snooze expires.';
    } else if (!masterOn) {
      headline = 'Notifications OFF';
      detail = 'Master toggle is off — flip it on to start receiving pushes.';
    } else {
      headline = 'Notifications ON';
      detail = 'Tap to manage channels, snooze, quiet hours, or run a test push.';
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(RoutePaths.settings),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                muted ? Icons.notifications_paused : Icons.notifications_active,
                color: tone,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      headline,
                      style: TextStyle(
                        color: tone,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.steel, margin: const EdgeInsets.symmetric(horizontal: 14));
}

// ---- Prompt dialog ----------------------------------------------------------

class _PromptDialog extends StatelessWidget {
  const _PromptDialog({
    required this.title,
    required this.hint,
    required this.controller,
    required this.submitLabel,
    this.obscure = false,
    this.keyboardType,
  });
  final String title;
  final String hint;
  final TextEditingController controller;
  final String submitLabel;
  final bool obscure;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.graphite,
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      content: TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: true,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.steel),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.gold),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.obsidian,
          ),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(submitLabel),
        ),
      ],
    );
  }
}
