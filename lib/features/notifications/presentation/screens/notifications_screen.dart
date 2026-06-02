import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../admin/presentation/providers/admin_providers.dart';

/// In-app notification center. Shows the last 50 broadcast pushes the user
/// could have received, with the same deeplink each push had originally so
/// taps reuse the existing FCM tap handler.
///
/// May 2026 update: per-channel filter chips at the top let the user
/// narrow to Hot Trades / Scanner / Chat / Recap / etc. Filter is a pure
/// client-side cut on the already-loaded list — no extra API calls.
///
/// Filter selection is in-memory only (resets to "All" on app restart).
/// Persistence across launches was scoped out of 2.1.0 to avoid pulling in
/// a shared_preferences dependency.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all';

  void _setFilter(String value) {
    setState(() => _filter = value);
  }

  /// Channel chip definitions. Ordered by likely-frequency so the most
  /// used filters are leftmost.
  static const List<_ChipDef> _chips = <_ChipDef>[
    _ChipDef('all', 'All', null),
    _ChipDef('hot', 'Hot', AppColors.bearish),
    _ChipDef('scanner', 'Scanner', AppColors.gold),
    _ChipDef('chat', 'Chat', AppColors.info),
    _ChipDef('premarket', 'Premarket', AppColors.warning),
    _ChipDef('recap', 'Recap', AppColors.bullish),
    _ChipDef('announcement', 'Announce', AppColors.warning),
  ];

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Map<String, dynamic>>> async =
        ref.watch(notificationHistoryProvider);
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SectionHeader(
                eyebrow: 'Inbox',
                title: 'Notifications',
              ),
            ),
            _ChannelFilterStrip(
              chips: _chips,
              active: _filter,
              onSelect: _setFilter,
              counts: _countByChannel(async.asData?.value ?? const []),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.graphite,
                onRefresh: () async {
                  ref.invalidate(notificationHistoryProvider);
                  await ref.read(notificationHistoryProvider.future);
                },
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (e, _) => ErrorState(
                    message: 'Could not load notifications',
                    details: e.toString(),
                    onRetry: () =>
                        ref.invalidate(notificationHistoryProvider),
                  ),
                  data: (items) {
                    final filtered = _filter == 'all'
                        ? items
                        : items
                            .where((m) => (m['channel'] ?? '') == _filter)
                            .toList(growable: false);
                    if (filtered.isEmpty) {
                      final isFiltered = _filter != 'all';
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          const SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.notifications_none,
                            title: isFiltered
                                ? 'No ${_chipLabelFor(_filter)} notifications'
                                : 'No notifications yet',
                            message: isFiltered
                                ? 'Try a different channel filter, or pull down to refresh.'
                                : 'Push alerts, scanner publishes, and recaps will appear here.',
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _NotificationRow(
                        item: PushHistoryItem.fromMap(filtered[i]),
                      ),
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

  /// Tally pushes per-channel so the chip header can show a count badge
  /// (e.g. "Hot · 7"). Pure client-side from the already-fetched list.
  Map<String, int> _countByChannel(List<Map<String, dynamic>> items) {
    final out = <String, int>{'all': items.length};
    for (final m in items) {
      final c = (m['channel'] ?? '').toString();
      if (c.isEmpty) continue;
      out[c] = (out[c] ?? 0) + 1;
    }
    return out;
  }

  String _chipLabelFor(String key) {
    for (final c in _chips) {
      if (c.key == key) return c.label;
    }
    return key;
  }
}

class _ChipDef {
  const _ChipDef(this.key, this.label, this.tone);
  final String key;
  final String label;
  /// null on the "All" chip; otherwise the channel's identity color.
  final Color? tone;
}

class _ChannelFilterStrip extends StatelessWidget {
  const _ChannelFilterStrip({
    required this.chips,
    required this.active,
    required this.onSelect,
    required this.counts,
  });
  final List<_ChipDef> chips;
  final String active;
  final ValueChanged<String> onSelect;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final c = chips[i];
            final isActive = c.key == active;
            final count = counts[c.key] ?? 0;
            final tone = c.tone ?? AppColors.gold;
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelect(c.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? tone.withValues(alpha: 0.16)
                        : AppColors.graphite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? tone.withValues(alpha: 0.7)
                          : AppColors.steel,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        c.label,
                        style: TextStyle(
                          color: isActive ? tone : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (count > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isActive
                                ? tone.withValues(alpha: 0.25)
                                : AppColors.steel,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: isActive
                                  ? tone
                                  : AppColors.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Loose model — just enough fields for the list. Backend returns more
/// (imageUrl, recipientCount) but we don't use them in v1.
class PushHistoryItem {
  const PushHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.channel,
    required this.source,
    required this.sentAt,
  });
  final String id;
  final String title;
  final String body;
  final String? deepLink;
  final String? channel;
  final String? source;
  final DateTime? sentAt;

  factory PushHistoryItem.fromMap(Map<String, dynamic> m) => PushHistoryItem(
        id: (m['id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        deepLink: m['deepLink'] as String?,
        channel: m['channel'] as String?,
        source: m['source'] as String?,
        sentAt: m['sentAt'] is String
            ? DateTime.tryParse(m['sentAt'] as String)
            : null,
      );
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});
  final PushHistoryItem item;

  Color get _channelTone {
    switch (item.channel) {
      case 'hot':
        return AppColors.bearish;
      case 'scanner':
        return AppColors.gold;
      case 'chat':
        return AppColors.info;
      case 'recap':
        return AppColors.bullish;
      case 'announcement':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  void _open(BuildContext context) {
    final dl = item.deepLink;
    if (dl == null || dl.isEmpty || !dl.startsWith('/')) return;
    context.go(dl);
  }

  @override
  Widget build(BuildContext context) {
    final tone = _channelTone;
    final ago = item.sentAt == null ? '' : _agoShort(item.sentAt!);
    final hasLink = item.deepLink != null && item.deepLink!.startsWith('/');
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasLink ? () => _open(context) : null,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.steel),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 6,
                height: 36,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (ago.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            ago,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    if (item.channel != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border:
                              Border.all(color: tone.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          item.channel!.toUpperCase(),
                          style: TextStyle(
                            color: tone,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasLink) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// History feed provider. Refetched when the user pulls down or visits the
/// screen fresh. No StreamProvider — pushes are rare enough that
/// pull-to-refresh is the right model.
final FutureProvider<List<Map<String, dynamic>>> notificationHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  final AdminRepository repo = ref.watch(adminRepositoryProvider);
  return repo.fetchMyNotificationHistory();
});

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}
