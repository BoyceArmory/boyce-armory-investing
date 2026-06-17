import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_state_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/data/tips_service.dart';

/// Compact gold banner shown on home until the user taps the X or
/// follows the lesson link. Highlights the v2.4.0 features (chat
/// badges + mute + search + snooze) so upgrade users discover them
/// without poking around.
///
/// The dismissal flag (`whatsNewV240`) lives in Firestore so closing
/// the banner on one device hides it on every other device the user
/// is signed in on.
class WhatsNewBanner extends ConsumerWidget {
  const WhatsNewBanner({super.key});

  static const String _tipId = 'whatsNewV240';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(isTipDismissedProvider(_tipId));
    if (dismissed) return const SizedBox.shrink();
    return _Banner(
      onTap: () {
        // Send the user to the new chat lesson; the snooze lesson is the
        // very next item in the same section so they'll see both.
        context.go(
          RoutePaths.lessonsLessonFor('execution', 'using-the-chat'),
        );
      },
      onDismiss: () async {
        final user = ref.read(currentFirebaseUserProvider);
        if (user == null) return;
        await ref.read(tipsServiceProvider).dismiss(user.uid, _tipId);
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppColors.gold.withValues(alpha: 0.18),
              AppColors.gold.withValues(alpha: 0.08),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: const TextSpan(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  children: <InlineSpan>[
                    TextSpan(
                      text: "What's new in v2.4 — ",
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text:
                          'chat @mentions + unread badges + mute per room, plus snooze-all and self-test push. Tap to learn.',
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close,
                  color: AppColors.textTertiary, size: 16),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ),
      ),
    );
  }
}
