import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Round profile avatar used in message rows. Falls back to initials when
/// there is no photoUrl. Admin status gets a gold ring + glow.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.senderName,
    required this.isAdmin,
    this.profileImageUrl,
    this.size = 36,
  });

  final String senderName;
  final bool isAdmin;
  final String? profileImageUrl;
  final double size;

  String get _initials {
    final String trimmed = senderName.trim();
    if (trimmed.isEmpty) return 'U';
    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto =
        profileImageUrl != null && profileImageUrl!.trim().isNotEmpty;
    final Color ring = isAdmin
        ? AppColors.gold.withValues(alpha: 0.75)
        : AppColors.steel;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 1.4),
        boxShadow: isAdmin
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: hasPhoto
            ? CachedNetworkImage(
                imageUrl: profileImageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallback(),
                placeholder: (_, __) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color:
          isAdmin ? AppColors.gold.withValues(alpha: 0.18) : AppColors.carbon,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: isAdmin ? AppColors.gold : AppColors.textPrimary,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
