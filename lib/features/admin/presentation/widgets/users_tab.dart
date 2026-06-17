import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/error_state.dart';
import '../providers/admin_providers.dart';
import 'user_detail_sheet.dart';

/// Users tab — lists users + a "Recent Activity" strip at the top showing
/// recent admin events (new signups, etc). Tapping an event scrolls to the
/// matching user in the list and highlights the row briefly. "View all"
/// opens a full bottom-sheet of every event.
class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});
  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  String _q = '';
  String? _busyUid;
  String? _highlightUid;
  final ScrollController _listCtrl = ScrollController();
  // Map of uid -> GlobalKey assigned on row build so we can locate a row
  // by Scrollable.ensureVisible(). Cleared on each filter change to avoid
  // stale keys piling up.
  final Map<String, GlobalKey> _rowKeys = {};

  /// Multi-select state. When non-null, the tab is in "bulk action"
  /// mode: a top bar shows the count + available bulk actions, taps on
  /// rows toggle selection rather than opening the detail sheet, and
  /// the popup menu is hidden so a row tap can't accidentally fire a
  /// single-row mutation mid-selection.
  Set<String>? _selectedUids;
  bool get _isMultiSelect => _selectedUids != null;

  /// True when we're running a bulk operation. Drives the spinner +
  /// disables the bar buttons.
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    // First time the Users tab opens, force-fresh both feeds. Subsequent
    // visits rely on pull-to-refresh (per user spec).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(adminEventsProvider);
      ref.invalidate(adminUsersProvider);
    });
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    super.dispose();
  }

  /// Shows a clear, branded snackbar. Used by every action callback so
  /// the admin sees a consistent confirm + a way to undo immediately
  /// where reasonable.
  void _toast(
    String message, {
    bool error = false,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? Colors.white : AppColors.obsidian,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            error ? AppColors.bearish : AppColors.gold,
        duration: Duration(seconds: error ? 6 : 3),
        action: action,
      ),
    );
  }

  /// Lookup the user's email for friendlier snackbar copy. We have it
  /// loaded already from listUsers — no extra round-trip.
  String _userLabel(String uid) {
    final list = ref.read(adminUsersProvider).asData?.value ?? const [];
    for (final u in list) {
      if ((u['uid'] ?? u['id'] ?? '').toString() == uid) {
        final e = (u['email'] ?? '').toString();
        if (e.isNotEmpty) return e;
        final n = (u['displayName'] ?? '').toString();
        if (n.isNotEmpty) return n;
      }
    }
    return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
  }

  Future<void> _setRole(String uid, String role) async {
    setState(() => _busyUid = uid);
    final label = _userLabel(uid);
    final previousRole = role == 'admin' ? 'customer' : 'admin';
    try {
      await ref.read(adminRepositoryProvider).setRole(uid, role);
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      _toast(
        role == 'admin'
            ? '$label is now an admin'
            : '$label demoted to customer',
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.obsidian,
          onPressed: () => _setRole(uid, previousRole),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Role change failed for $label: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _setTier(String uid, String tier) async {
    setState(() => _busyUid = uid);
    final label = _userLabel(uid);
    final previousTier = tier == 'premium' ? 'free' : 'premium';
    try {
      await ref.read(adminRepositoryProvider).setTier(uid, tier);
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      _toast(
        '$label tier → ${tier.toUpperCase()}',
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.obsidian,
          onPressed: () => _setTier(uid, previousTier),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Tier change failed for $label: $e', error: true);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _setDisabled(String uid, bool disabled) async {
    setState(() => _busyUid = uid);
    final label = _userLabel(uid);
    try {
      await ref.read(adminRepositoryProvider).setDisabled(uid, disabled);
      ref.invalidate(adminUsersProvider);
      if (!mounted) return;
      _toast(
        disabled
            ? '$label disabled — sign-in blocked'
            : '$label re-enabled',
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppColors.obsidian,
          onPressed: () => _setDisabled(uid, !disabled),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast(
        disabled
            ? 'Failed to disable $label: $e'
            : 'Failed to re-enable $label: $e',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  // ---- Multi-select / bulk action plumbing ---------------------------

  void _enterMultiSelect(String uid) {
    setState(() => _selectedUids = <String>{uid});
  }

  void _exitMultiSelect() {
    setState(() => _selectedUids = null);
  }

  void _toggleSelected(String uid) {
    setState(() {
      final set = _selectedUids ?? <String>{};
      if (set.contains(uid)) {
        set.remove(uid);
      } else {
        set.add(uid);
      }
      // Exit multi-select when the last selection is cleared so the
      // top bar disappears and rows go back to tap-to-detail behavior.
      _selectedUids = set.isEmpty ? null : set;
    });
  }

  /// Confirm dialog for destructive bulk actions. Returns false when
  /// the admin cancels.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
    Color actionColor = AppColors.gold,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.graphite,
        title: Text(title,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(message,
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel,
                style: TextStyle(
                    color: actionColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return r == true;
  }

  /// Runs [op] for every selected uid sequentially. Collects per-uid
  /// successes + failures and shows a summary toast at the end so the
  /// admin never has to wonder which rows the action actually applied
  /// to. Exits multi-select mode on success unless every uid failed.
  Future<void> _bulkApply(
    String actionVerb,
    Future<void> Function(String uid) op,
  ) async {
    final uids = _selectedUids?.toList() ?? const <String>[];
    if (uids.isEmpty) return;
    setState(() => _bulkBusy = true);
    int ok = 0;
    int failed = 0;
    for (final uid in uids) {
      try {
        await op(uid);
        ok++;
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(adminUsersProvider);
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      if (failed == 0) _selectedUids = null;
    });
    final summary = failed == 0
        ? '$actionVerb applied to $ok user${ok == 1 ? '' : 's'}'
        : '$actionVerb: $ok succeeded, $failed failed';
    _toast(summary, error: failed > 0);
  }

  Future<void> _bulkMakeAdmin() async {
    final n = _selectedUids?.length ?? 0;
    if (!await _confirm(
      title: 'Make $n user${n == 1 ? '' : 's'} admin?',
      message:
          'They will gain full access to the admin dashboard and every '
          'destructive action it exposes. Reversible via Demote.',
      actionLabel: 'Make admin',
    )) {
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    await _bulkApply(
        'Make admin', (uid) => repo.setRole(uid, 'admin'));
  }

  Future<void> _bulkDemote() async {
    final n = _selectedUids?.length ?? 0;
    if (!await _confirm(
      title: 'Demote $n user${n == 1 ? '' : 's'} to customer?',
      message: 'They will lose admin access.',
      actionLabel: 'Demote',
    )) {
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    await _bulkApply(
        'Demote', (uid) => repo.setRole(uid, 'customer'));
  }

  Future<void> _bulkSetTier(String tier) async {
    final n = _selectedUids?.length ?? 0;
    if (!await _confirm(
      title: 'Set tier to ${tier.toUpperCase()}?',
      message: 'Applies to $n user${n == 1 ? '' : 's'}.',
      actionLabel: 'Set tier',
    )) {
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    await _bulkApply(
        'Tier → ${tier.toUpperCase()}', (uid) => repo.setTier(uid, tier));
  }

  Future<void> _bulkSetDisabled(bool disabled) async {
    final n = _selectedUids?.length ?? 0;
    if (!await _confirm(
      title: disabled
          ? 'Disable $n user${n == 1 ? '' : 's'}?'
          : 'Re-enable $n user${n == 1 ? '' : 's'}?',
      message: disabled
          ? 'Selected users will be blocked from signing in.'
          : 'Selected users will regain sign-in access.',
      actionLabel: disabled ? 'Disable' : 'Re-enable',
      actionColor: disabled ? AppColors.bearish : AppColors.gold,
    )) {
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    await _bulkApply(
      disabled ? 'Disable' : 'Re-enable',
      (uid) => repo.setDisabled(uid, disabled),
    );
  }

  /// Marks an admin event as read on the server, then refreshes the strip.
  Future<void> _markEventRead(String eventId) async {
    try {
      await ref.read(adminRepositoryProvider).markAdminEventRead(eventId);
      ref.invalidate(adminEventsProvider);
    } catch (_) {
      // Non-blocking — the user still got the navigation; we don't need
      // to interrupt their flow with a snackbar for a stat-tracking call.
    }
  }

  /// Jumps the user list to the row matching [uid], expands the search
  /// filter so the row is visible, and flashes a gold border for ~2s.
  Future<void> _jumpToUser(String uid) async {
    // Clear search so the row is guaranteed to be in the filtered list.
    if (_q.isNotEmpty) {
      setState(() => _q = '');
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    final key = _rowKeys[uid];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.15,
      );
    }
    if (!mounted) return;
    setState(() => _highlightUid = uid);
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_highlightUid == uid) setState(() => _highlightUid = null);
    });
  }

  void _openAllEventsSheet(List<Map<String, dynamic>> events) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.graphite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: AppColors.steel,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: AppColors.gold, size: 18),
                  SizedBox(width: 8),
                  Text('All Activity',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(color: AppColors.steel, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: events.length,
                separatorBuilder: (_, __) => const Divider(
                    color: AppColors.steel, height: 16),
                itemBuilder: (_, i) {
                  final e = events[i];
                  return _EventListTile(
                    event: e,
                    onTap: () {
                      Navigator.of(context).maybePop();
                      final uid = (e['uid'] ?? '').toString();
                      final id = (e['id'] ?? '').toString();
                      if (id.isNotEmpty) _markEventRead(id);
                      if (uid.isNotEmpty) _jumpToUser(uid);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final eventsAsync = ref.watch(adminEventsProvider);
    final unreadCount = ref.watch(adminEventsUnreadCountProvider);

    return Column(
      children: [
        // --- Bulk action bar (only when multi-select is active) ---
        if (_isMultiSelect)
          _BulkActionBar(
            count: _selectedUids!.length,
            busy: _bulkBusy,
            onCancel: _exitMultiSelect,
            onMakeAdmin: _bulkMakeAdmin,
            onDemote: _bulkDemote,
            onSetPremium: () => _bulkSetTier('premium'),
            onSetFree: () => _bulkSetTier('free'),
            onDisable: () => _bulkSetDisabled(true),
            onEnable: () => _bulkSetDisabled(false),
          ),

        // --- Recent Activity strip (hidden in multi-select to keep
        // the bulk bar dominant) ---
        if (!_isMultiSelect)
          eventsAsync.when(
            loading: () => const _ActivityStripSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (events) {
              if (events.isEmpty) return const SizedBox.shrink();
              return _RecentActivityStrip(
                events: events.take(5).toList(),
                totalCount: events.length,
                unreadCount: unreadCount,
                onTapEvent: (e) {
                  final uid = (e['uid'] ?? '').toString();
                  final id = (e['id'] ?? '').toString();
                  if (id.isNotEmpty) _markEventRead(id);
                  if (uid.isNotEmpty) _jumpToUser(uid);
                },
                onViewAll: () => _openAllEventsSheet(events),
              );
            },
          ),

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
              ref.invalidate(adminEventsProvider);
              await Future.wait<dynamic>([
                ref.read(adminUsersProvider.future),
                ref.read(adminEventsProvider.future),
              ]);
            },
            child: usersAsync.when(
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

                // Drop any stale row keys not in the filtered set so the
                // map doesn't grow forever as the user types.
                final filteredIds = filtered
                    .map((u) => (u['uid'] ?? u['id'] ?? '').toString())
                    .toSet();
                _rowKeys.removeWhere((k, _) => !filteredIds.contains(k));

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
                  controller: _listCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final uid = (u['uid'] ?? u['id'] ?? '').toString();
                    final role = (u['role'] ?? 'customer').toString();
                    final tier = (u['tier'] ?? 'free').toString();
                    final disabled = u['disabled'] == true;
                    final createdAt = (u['createdAt'] ?? '').toString();
                    final isNew = _isWithinLast24h(createdAt);
                    final rowKey = _rowKeys.putIfAbsent(uid, () => GlobalKey());
                    final isSelected =
                        _selectedUids?.contains(uid) ?? false;
                    return _UserRow(
                      key: rowKey,
                      email: (u['email'] ?? 'no email').toString(),
                      uid: uid,
                      role: role,
                      tier: tier,
                      disabled: disabled,
                      isNew: isNew,
                      highlighted: _highlightUid == uid,
                      busy: _busyUid == uid,
                      selected: isSelected,
                      multiSelectActive: _isMultiSelect,
                      // In multi-select: tap toggles, long-press is no-op.
                      // Otherwise: tap opens detail, long-press enters
                      // multi-select and selects this row.
                      onTap: () {
                        if (_isMultiSelect) {
                          _toggleSelected(uid);
                        } else {
                          UserDetailSheet.show(context, uid);
                        }
                      },
                      onLongPress: () {
                        if (!_isMultiSelect) _enterMultiSelect(uid);
                      },
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

/// Returns true if the ISO timestamp [iso] is within the last 24 hours.
bool _isWithinLast24h(String iso) {
  if (iso.isEmpty) return false;
  final t = DateTime.tryParse(iso);
  if (t == null) return false;
  return DateTime.now().difference(t.toLocal()).inHours < 24;
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

class _RecentActivityStrip extends StatelessWidget {
  const _RecentActivityStrip({
    required this.events,
    required this.totalCount,
    required this.unreadCount,
    required this.onTapEvent,
    required this.onViewAll,
  });
  final List<Map<String, dynamic>> events;
  final int totalCount;
  final int unreadCount;
  final void Function(Map<String, dynamic>) onTapEvent;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.gold, size: 14),
              const SizedBox(width: 4),
              const Text('Recent Activity',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4)),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                  ),
                  child: Text('$unreadCount',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onViewAll,
                child: Text('View all ($totalCount)',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _EventCard(
                event: events[i],
                onTap: () => onTapEvent(events[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStripSkeleton extends StatelessWidget {
  const _ActivityStripSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SizedBox(
        height: 90,
        child: Center(
          child: SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = (event['kind'] ?? 'event').toString();
    final unread = (event['read'] as bool? ?? false) == false;
    final display = (event['displayName'] ?? event['email'] ?? 'user').toString();
    final logged = (event['loggedAt'] ?? event['createdAt'] ?? '').toString();
    final (icon, color, label) = _kindMeta(kind);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.graphite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: unread ? AppColors.gold.withValues(alpha: 0.5) : AppColors.steel,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4)),
                const Spacer(),
                if (unread)
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Text(display,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w700)),
            Text(_timeAgo(logged),
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  const _EventListTile({required this.event, required this.onTap});
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = (event['kind'] ?? 'event').toString();
    final unread = (event['read'] as bool? ?? false) == false;
    final display = (event['displayName'] ?? event['email'] ?? 'user').toString();
    final email = (event['email'] ?? '').toString();
    final logged = (event['loggedAt'] ?? event['createdAt'] ?? '').toString();
    final (icon, color, label) = _kindMeta(kind);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
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
                              color: AppColors.textTertiary, fontSize: 10)),
                      if (unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(display,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  if (email.isNotEmpty && email != display)
                    Text(email,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Returns (icon, color, short label) for an admin_event kind.
/// Centralized so the card + the list-tile + future surfaces stay in sync.
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

class _UserRow extends StatelessWidget {
  const _UserRow({
    super.key,
    required this.email,
    required this.uid,
    required this.role,
    required this.tier,
    required this.disabled,
    required this.isNew,
    required this.highlighted,
    required this.busy,
    required this.onAction,
    required this.onTap,
    required this.onLongPress,
    required this.selected,
    required this.multiSelectActive,
  });
  final String email;
  final String uid;
  final String role;
  final String tier;
  final bool disabled;
  final bool isNew;
  final bool highlighted;
  final bool busy;
  final void Function(String action) onAction;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;
  final bool multiSelectActive;

  @override
  Widget build(BuildContext context) {
    // Border + shadow color emphasis prioritized:
    //   selected (gold-filled glow) > highlighted (gold border) > steel.
    final Color borderColor = selected || highlighted
        ? AppColors.gold
        : AppColors.steel;
    final double borderWidth = (selected || highlighted) ? 1.5 : 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.graphite,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(12),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      // The whole row is now a tap target — single-tap opens the detail
      // sheet (or toggles selection in multi-select mode). Long-press
      // enters multi-select. PopupMenu is hidden in multi-select so a
      // popup-driven single-row mutation can't fire while the admin is
      // composing a bulk action.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
        children: [
          if (multiSelectActive) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                selected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
                color:
                    selected ? AppColors.gold : AppColors.textTertiary,
              ),
            ),
          ],
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
                  if (isNew) ...const [
                    SizedBox(width: 4),
                    _UserBadge(label: 'NEW', color: AppColors.gold),
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
              : multiSelectActive
                  // In multi-select, hide the popup to avoid a single-row
                  // action firing while the admin is composing a bulk
                  // action. A small placeholder keeps row height stable.
                  ? const SizedBox(width: 8)
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
          ),
        ),
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

/// Top action bar shown when multi-select is active. Lists the selected
/// count + every bulk action that makes sense across multiple users.
/// Buttons disable while a bulk operation is running.
class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.count,
    required this.busy,
    required this.onCancel,
    required this.onMakeAdmin,
    required this.onDemote,
    required this.onSetPremium,
    required this.onSetFree,
    required this.onDisable,
    required this.onEnable,
  });
  final int count;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onMakeAdmin;
  final VoidCallback onDemote;
  final VoidCallback onSetPremium;
  final VoidCallback onSetFree;
  final VoidCallback onDisable;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: busy ? null : onCancel,
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close,
                    color: AppColors.gold, size: 18),
              ),
              Text(
                '$count selected',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.gold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _BulkBtn(
                  label: 'Make admin',
                  icon: Icons.shield,
                  onTap: onMakeAdmin,
                  busy: busy,
                ),
                _BulkBtn(
                  label: 'Demote',
                  icon: Icons.shield_outlined,
                  onTap: onDemote,
                  busy: busy,
                ),
                _BulkBtn(
                  label: 'Tier → premium',
                  icon: Icons.upgrade,
                  onTap: onSetPremium,
                  busy: busy,
                ),
                _BulkBtn(
                  label: 'Tier → free',
                  icon: Icons.downloading,
                  onTap: onSetFree,
                  busy: busy,
                ),
                _BulkBtn(
                  label: 'Disable',
                  icon: Icons.block,
                  onTap: onDisable,
                  busy: busy,
                  color: AppColors.bearish,
                ),
                _BulkBtn(
                  label: 'Enable',
                  icon: Icons.lock_open,
                  onTap: onEnable,
                  busy: busy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.busy,
    this.color,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.gold;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton.icon(
        onPressed: busy ? null : onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          backgroundColor: AppColors.carbon,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: c.withValues(alpha: 0.45)),
          ),
        ),
        icon: Icon(icon, size: 14, color: c),
        label: Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
