import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/datetime_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/chat_models.dart';
import 'chat_avatar.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.currentUid,
    required this.onLongPress,
    required this.onTapImage,
    required this.onToggleReaction,
  });

  final ChatMessage message;
  final String currentUid;
  final VoidCallback onLongPress;
  final ValueChanged<String> onTapImage;
  final ValueChanged<String> onToggleReaction;

  @override
  Widget build(BuildContext context) {
    if (message.deleted) return const _DeletedBubble();
    final Color borderColor = message.isAdmin
        ? AppColors.gold.withValues(alpha: 0.55)
        : AppColors.steel;
    final List<BoxShadow>? shadow = message.isAdmin
        ? <BoxShadow>[
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ]
        : null;

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.graphite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Header(message: message),
            if (message.text.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 45),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if (message.hasImage) ...<Widget>[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 45),
                child: _ImageBlock(
                  url: message.imageUrl!,
                  onTap: () => onTapImage(message.imageUrl!),
                ),
              ),
            ],
            if (message.reactions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 45),
                child: _ReactionBar(
                  reactions: message.reactions,
                  currentUid: currentUid,
                  onTap: onToggleReaction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        ChatAvatar(
          senderName: message.senderName,
          isAdmin: message.isAdmin,
          profileImageUrl: message.profileImageUrl,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: <Widget>[
              Text(
                message.senderName,
                style: TextStyle(
                  color: message.isAdmin
                      ? AppColors.gold
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message.isAdmin)
                const Icon(
                  Icons.verified,
                  color: AppColors.gold,
                  size: 14,
                ),
              if (message.edited)
                const Text(
                  'edited',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        Text(
          message.createdAt.ago,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.url, required this.onTap});
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                height: 120,
                alignment: Alignment.center,
                color: AppColors.carbon,
                child: const Text(
                  'Image failed to load',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.zoom_out_map,
                      color: Colors.white, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'Tap to view',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.reactions,
    required this.currentUid,
    required this.onTap,
  });
  final Map<String, List<String>> reactions;
  final String currentUid;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: reactions.entries.map((MapEntry<String, List<String>> e) {
        final bool selected =
            currentUid.isNotEmpty && e.value.contains(currentUid);
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onTap(e.key),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.18)
                  : AppColors.carbon,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.steel,
              ),
            ),
            child: Text(
              '${e.key} ${e.value.length}',
              style: TextStyle(
                color: selected ? AppColors.gold : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.steel),
      ),
      child: const Text(
        'Message deleted',
        style: TextStyle(
          color: AppColors.textTertiary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
