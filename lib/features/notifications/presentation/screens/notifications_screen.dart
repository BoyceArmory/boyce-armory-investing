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
/// Lives at `/notifications`. Tap from the home page (bell icon) or from
/// any push that the user dismissed but later wants to find again.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const <Widget>[
                          SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.notifications_none,
                            title: 'No notifications yet',
                            message:
                                'Push alerts, scanner publishes, and recaps will appear here.',
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _NotificationRow(
                        item: PushHistoryItem.fromMap(items[i]),
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
