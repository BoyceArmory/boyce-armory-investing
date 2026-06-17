import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/responsive_container.dart';
import '../providers/admin_providers.dart';

/// Admin Notifications inbox — full-screen list of every admin_event
/// (new signups, support tickets, role/tier changes, etc).
///
/// This is the deep-link target for FCM pushes fired by the
/// new-account-watcher cron (kind: "admin_event"). Tapping a notification
/// while running, or cold-starting from one, routes here via
/// [_handleNotificationTap] in app.dart.
///
/// Sources: same `adminEventsProvider` the Users tab Recent Activity
/// strip reads from, so invalidating either refreshes both.
class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

/// Filter chip values. Matches the `kind` field on admin_events for
/// simple filters; "all" bypasses the filter.
enum _EventFilter { all, newAccount, support, roleTier }

extension on _EventFilter {
  String get label {
    switch (this) {
      case _EventFilter.all:
        return 'All';
      case _EventFilter.newAccount:
        return 'Signups';
      case _EventFilter.support:
        return 'Support';
      case _EventFilter.roleTier:
        return 'Role / Tier';
    }
  }

  /// Returns true if [kind] passes this filter.
  bool matches(String kind) {
    switch (this) {
      case _EventFilter.all:
        return true;
      case _EventFilter.newAccount:
        return kind == 'new_account';
      case _EventFilter.support:
        return kind == 'support_ticket';
      case _EventFilter.roleTier:
        return kind == 'role_change' || kind == 'tier_change';
    }
  }
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  _EventFilter _filter = _EventFilter.all;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    // Refresh on entry so the inbox reflects the very latest server state
    // (push arrived → user tapped → we want the new doc visible).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adminEventsProvider);
    });
  }

  Future<void> _markRead(String id) async {
    try {
      await ref.read(adminRepositoryProvider).markAdminEventRead(id);
      ref.invalidate(adminEventsProvider);
    } catch (_) {
      // Best-effort; don't interrupt the user with a snackbar for a
      // background read flag.
    }
  }

  Future<void> _markAllRead(List<Map<String, dynamic>> events) async {
    final unread = events
        .where((e) => (e['read'] as bool? ?? false) == false)
        .toList();
    if (unread.isEmpty) return;
    setState(() => _markingAllRead = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      // Fire sequentially to keep server load predictable. Inbox is small
      // (<= 50) so this completes in well under a second.
      for (final e in unread) {
        final id = (e['id'] ?? '').toString();
        if (id.isEmpty) continue;
        try {
          await repo.markAdminEventRead(id);
        } catch (_) {
          // Continue on individual failures.
        }
      }
      ref.invalidate(adminEventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked ${unread.length} as read')),
      );
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(adminEventsProvider);
    final unreadCount = ref.watch(adminEventsUnreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        backgroundColor: AppColors.obsidian,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // Cold-start path — no back stack. Go to the admin dashboard.
              context.go('/admin');
            }
          },
        ),
        title: Row(
          children: [
            const Text('Notifications',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Text('$unreadCount',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
        actions: [
          eventsAsync.maybeWhen(
            data: (list) => unreadCount > 0
                ? TextButton.icon(
                    onPressed: _markingAllRead ? null : () => _markAllRead(list),
                    icon: _markingAllRead
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.gold))
                        : const Icon(Icons.done_all,
                            color: AppColors.gold, size: 16),
                    label: const Text('Mark all read',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
            // Filter chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: _EventFilter.values.map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f.label,
                          style: TextStyle(
                              color: selected
                                  ? AppColors.obsidian
                                  : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      selected: selected,
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.graphite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                            color: selected
                                ? AppColors.gold
                                : AppColors.steel),
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.graphite,
                onRefresh: () async {
                  ref.invalidate(adminEventsProvider);
                  await ref.read(adminEventsProvider.future);
                },
                child: eventsAsync.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.gold)),
                  error: (e, _) => ErrorState(
                    message: 'Could not load notifications',
                    details: e.toString(),
                    onRetry: () => ref.invalidate(adminEventsProvider),
                  ),
                  data: (list) {
                    final filtered = list
                        .where((e) =>
                            _filter.matches((e['kind'] ?? '').toString()))
                        .toList();
                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 100),
                          Center(
                            child: Column(
                              children: [
                                const Icon(Icons.inbox,
                                    color: AppColors.textTertiary, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  _filter == _EventFilter.all
                                      ? 'No notifications yet'
                                      : 'No ${_filter.label.toLowerCase()} notifications',
                                  style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        return _NotificationRow(
                          event: e,
                          onTap: () {
                            final id = (e['id'] ?? '').toString();
                            if (id.isNotEmpty) _markRead(id);
                            // We don't navigate from the inbox — the row
                            // surfaces all the relevant info inline.
                            // (Drill-down to user detail can come in a
                            // later slice if needed.)
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the inbox. Shows kind icon, display name, email, time-ago,
/// and an unread gold dot. Tap marks read.
class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.event, required this.onTap});
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = (event['kind'] ?? 'event').toString();
    final unread = (event['read'] as bool? ?? false) == false;
    final display = (event['displayName'] ?? event['email'] ?? 'user').toString();
    final email = (event['email'] ?? '').toString();
    final logged =
        (event['loggedAt'] ?? event['createdAt'] ?? '').toString();
    final (icon, color, label) = _kindMeta(kind);

    return Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unread
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : AppColors.steel,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4)),
                        const SizedBox(width: 6),
                        Text(_timeAgo(logged),
                            style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10)),
                        const Spacer(),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (email.isNotEmpty && email != display) ...[
                      const SizedBox(height: 1),
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact human-friendly duration ("3m", "1h", "2d") since [iso].
String _timeAgo(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}

/// (icon, color, label) for an admin_event kind. Mirrors the helper in
/// users_tab.dart — kept in two places intentionally so the two surfaces
/// can evolve independently if needed, but with identical defaults today.
(IconData, Color, String) _kindMeta(String kind) {
  switch (kind) {
    case 'new_account':
      return (Icons.person_add, AppColors.gold, 'NEW SIGNUP');
    case 'support_ticket':
      return (Icons.help_outline, AppColors.bullish, 'SUPPORT');
    case 'role_change':
      return (Icons.shield_outlined, AppColors.textSecondary, 'ROLE');
    case 'tier_change':
      return (Icons.upgrade, AppColors.bullish, 'TIER');
    default:
      return (Icons.bolt, AppColors.textSecondary, kind.toUpperCase());
  }
}
