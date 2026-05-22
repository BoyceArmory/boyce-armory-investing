import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';

/// Users tab — list users, change role/tier/disabled.
class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});
  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  String _q = '';
  String? _busyUid;

  Future<void> _setRole(String uid, String role) async {
    setState(() => _busyUid = uid);
    try {
      await ref.read(adminRepositoryProvider).setRole(uid, role);
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role set: $role')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _setTier(String uid, String tier) async {
    setState(() => _busyUid = uid);
    try {
      await ref.read(adminRepositoryProvider).setTier(uid, tier);
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tier set: $tier')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _setDisabled(String uid, bool disabled) async {
    setState(() => _busyUid = uid);
    try {
      await ref.read(adminRepositoryProvider).setDisabled(uid, disabled);
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(disabled ? 'User disabled' : 'User enabled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.bearish),
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminUsersProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by email or uid',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 18),
              filled: true,
              fillColor: AppColors.graphite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.steel),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.graphite,
            onRefresh: () async {
              ref.invalidate(adminUsersProvider);
              await ref.read(adminUsersProvider.future);
            },
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => ErrorState(
                message: 'Could not load users',
                details: e.toString(),
                onRetry: () => ref.invalidate(adminUsersProvider),
              ),
              data: (list) {
                final filtered = _q.isEmpty
                    ? list
                    : list.where((u) {
                        final email = (u['email'] ?? '').toString().toLowerCase();
                        final uid = (u['uid'] ?? u['id'] ?? '').toString().toLowerCase();
                        final name = (u['displayName'] ?? '').toString().toLowerCase();
                        return email.contains(_q) || uid.contains(_q) || name.contains(_q);
                      }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No users match.',
                          style: TextStyle(color: AppColors.textTertiary))),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final uid = (u['uid'] ?? u['id'] ?? '').toString();
                    final role = (u['role'] ?? 'customer').toString();
                    final tier = (u['tier'] ?? 'free').toString();
                    final disabled = u['disabled'] == true;
                    return _UserRow(
                      email: (u['email'] ?? 'no email').toString(),
                      uid: uid,
                      role: role,
                      tier: tier,
                      disabled: disabled,
                      busy: _busyUid == uid,
                      onAction: (action) {
                        switch (action) {
                          case 'role_admin':
                            _setRole(uid, 'admin');
                            break;
                          case 'role_customer':
                            _setRole(uid, 'customer');
                            break;
                          case 'tier_premium':
                            _setTier(uid, 'premium');
                            break;
                          case 'tier_free':
                            _setTier(uid, 'free');
                            break;
                          case 'disable':
                            _setDisabled(uid, true);
                            break;
                          case 'enable':
                            _setDisabled(uid, false);
                            break;
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.email,
    required this.uid,
    required this.role,
    required this.tier,
    required this.disabled,
    required this.busy,
    required this.onAction,
  });
  final String email;
  final String uid;
  final String role;
  final String tier;
  final bool disabled;
  final bool busy;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.steel),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(uid,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  _UserBadge(label: role.toUpperCase(),
                      color: role == 'admin' ? AppColors.gold : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  _UserBadge(label: tier.toUpperCase(),
                      color: tier == 'premium' ? AppColors.bullish : AppColors.textTertiary),
                  if (disabled) ...const [
                    SizedBox(width: 4),
                    _UserBadge(label: 'DISABLED', color: AppColors.bearish),
                  ],
                ]),
              ],
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                )
              : PopupMenuButton<String>(
                  color: AppColors.graphite,
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 18),
                  itemBuilder: (_) => [
                    if (role != 'admin') const PopupMenuItem(value: 'role_admin', child: Text('Make admin')),
                    if (role == 'admin') const PopupMenuItem(value: 'role_customer', child: Text('Demote to customer')),
                    const PopupMenuDivider(),
                    if (tier != 'premium') const PopupMenuItem(value: 'tier_premium', child: Text('Set tier: premium')),
                    if (tier == 'premium') const PopupMenuItem(value: 'tier_free', child: Text('Set tier: free')),
                    const PopupMenuDivider(),
                    if (!disabled) const PopupMenuItem(value: 'disable', child: Text('Disable user')),
                    if (disabled) const PopupMenuItem(value: 'enable', child: Text('Re-enable user')),
                  ],
                  onSelected: onAction,
                ),
        ],
      ),
    );
  }
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}
