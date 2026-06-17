import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../data/chat_models.dart';
import '../providers/chat_providers.dart';

/// Chat tab: header banner on top, then one full-bleed image tile per room.
/// Each tile renders the room artwork edge-to-edge (no inner icon box) and
/// is fully tappable.
class ChatHomeScreen extends ConsumerWidget {
  const ChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ChatRoomDef> rooms = ref.watch(chatRoomsProvider);

    final totalUnread = ref.watch(chatTotalUnreadProvider);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const ScreenHeader(asset: AssetPaths.headerChatRoom),
          if (totalUnread > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _UnreadSummaryStrip(totalUnread: totalUnread),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < rooms.length; i++) ...<Widget>[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 60 + 50 * i),
                    child: _RoomTile(room: rooms[i]),
                  ),
                  if (i < rooms.length - 1) const SizedBox(height: 14),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header strip shown on chat home when at least one room has unread
/// messages. Tapping "Mark all read" stamps lastRead = now across every
/// configured room in a single Firestore write so every per-room badge
/// + the bottom-nav rollup clear at once.
class _UnreadSummaryStrip extends ConsumerStatefulWidget {
  const _UnreadSummaryStrip({required this.totalUnread});
  final int totalUnread;

  @override
  ConsumerState<_UnreadSummaryStrip> createState() =>
      _UnreadSummaryStripState();
}

class _UnreadSummaryStripState extends ConsumerState<_UnreadSummaryStrip> {
  bool _working = false;

  Future<void> _markAll() async {
    if (_working) return;
    final user = ref.read(currentFirebaseUserProvider);
    if (user == null) {
      context.showSnack('Sign in to manage chat.', isError: true);
      return;
    }
    setState(() => _working = true);
    try {
      final roomIds = ref
          .read(chatRoomsProvider)
          .map((r) => r.id)
          .toList(growable: false);
      await ref
          .read(chatPrefsServiceProvider)
          .markAllRoomsRead(user.uid, roomIds);
      if (mounted) context.showSnack('All rooms marked as read');
    } catch (e) {
      if (mounted) context.showSnack('Failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.mark_chat_unread, color: AppColors.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.totalUnread >= 99
                  ? '99+ unread messages'
                  : widget.totalUnread == 1
                      ? '1 unread message'
                      : '${widget.totalUnread} unread messages',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: _working ? null : _markAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gold,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _working
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : const Text(
                    'Mark all read',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Full-width image tile that *is* the room button. The artwork fills the
/// entire rectangle. An unread badge is overlaid in the top-right corner
/// when there are messages newer than the user's lastRead for this room
/// (and the room isn't muted). A small mute icon appears bottom-right
/// when the room is muted so the absence-of-badge isn't mysterious.
class _RoomTile extends ConsumerWidget {
  const _RoomTile({required this.room});
  final ChatRoomDef room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BorderRadius radius = BorderRadius.circular(18);
    final muted = ref.watch(chatRoomMutedProvider(room.id));
    final unreadAsync = ref.watch(chatRoomUnreadCountProvider(room.id));
    final unread = unreadAsync.maybeWhen(data: (n) => n, orElse: () => 0);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        splashColor: AppColors.gold.withValues(alpha: 0.10),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        onTap: () => context.go(RoutePaths.chatRoomFor(room.id)),
        child: Stack(
          children: [
            Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: AppColors.graphite,
                border: Border.all(color: AppColors.steel),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: room.iconAsset != null
                    ? Image.asset(
                        room.iconAsset!,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        errorBuilder: (_, __, ___) => _Fallback(room: room),
                      )
                    : _Fallback(room: room),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: 10,
                right: 10,
                child: _UnreadBadge(count: unread),
              ),
            if (muted)
              const Positioned(
                bottom: 10,
                right: 10,
                child: _MutedChip(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gold unread-count badge — capped at 99+. Matches the rest of the
/// admin/inbox badges in the app for visual consistency.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count >= 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.obsidian,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Subtle muted indicator — bottom-right of the tile.
class _MutedChip extends StatelessWidget {
  const _MutedChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.textTertiary.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off,
              size: 11, color: AppColors.textTertiary),
          SizedBox(width: 4),
          Text('Muted',
              style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Renders the legacy icon+title row when an artwork asset is missing.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.room});
  final ChatRoomDef room;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Icon(room.icon, color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(room.title, style: tt.titleMedium),
                const SizedBox(height: 4),
                Text(room.description, style: tt.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
