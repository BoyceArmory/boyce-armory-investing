import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../providers/profile_providers.dart';

/// Tappable round avatar. Shows the current photo (or initials fallback), and
/// tapping it kicks off an image-picker -> Firebase Storage upload.
class AvatarUploader extends ConsumerStatefulWidget {
  const AvatarUploader({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.size = 64,
    this.onUploaded,
  });

  final String? photoUrl;
  final String initials;
  final double size;
  final VoidCallback? onUploaded;

  @override
  ConsumerState<AvatarUploader> createState() => _AvatarUploaderState();
}

class _AvatarUploaderState extends ConsumerState<AvatarUploader> {
  bool _uploading = false;

  Future<void> _onTap() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final String? url = await ref
          .read(profileRepositoryProvider)
          .pickAndUploadAvatar();
      if (!mounted) return;
      if (url != null) {
        context.showSnack('Profile photo updated.');
        widget.onUploaded?.call();
      }
    } catch (e) {
      if (mounted) context.showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final bool hasPhoto =
        widget.photoUrl != null && widget.photoUrl!.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(s),
      onTap: _onTap,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasPhoto ? null : AppGradients.gold,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipOval(
              child: hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: widget.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _initialsFallback(s),
                      placeholder: (_, __) => _initialsFallback(s),
                    )
                  : _initialsFallback(s),
            ),
          ),
          // Camera badge overlay.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.obsidian,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 12,
                color: AppColors.gold,
              ),
            ),
          ),
          if (_uploading)
            Container(
              width: s,
              height: s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialsFallback(double size) {
    return Container(
      color: AppColors.gold,
      alignment: Alignment.center,
      child: Text(
        widget.initials,
        style: TextStyle(
          color: AppColors.obsidian,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
