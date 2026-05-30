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
