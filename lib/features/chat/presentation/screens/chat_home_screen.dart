import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
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

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const ScreenHeader(asset: AssetPaths.headerChatRoom),
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

/// Full-width image tile that *is* the room button. The artwork fills the
/// entire rectangle; nothing else is drawn on top.
class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});
  final ChatRoomDef room;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        splashColor: AppColors.gold.withValues(alpha: 0.10),
        highlightColor: AppColors.gold.withValues(alpha: 0.05),
        onTap: () => context.go(RoutePaths.chatRoomFor(room.id)),
        child: Ink(
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
