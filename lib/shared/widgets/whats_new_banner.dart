import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_state_provider.dart';
import '../../core/routing/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/data/tips_service.dart';

/// Compact gold banner shown on home until the user taps the X or
/// follows the lesson link. Highlights the v2.5.0 features (0DTE
/// scalp mode opt-in + Hot Trades scalp tab + theta-per-minute on
/// scalp cards) so upgrade users discover them without poking around.
///
/// The dismissal flag (`whatsNewV250`) lives in Firestore so closing
/// the banner on one device hides it on every other device the user
/// is signed in on. Bumping the tip ID per release naturally re-shows
/// the banner to everyone who dismissed the prior version.
class WhatsNewBanner extends ConsumerWidget {
  const WhatsNewBanner({super.key});

  static const String _tipId = 'whatsNewV250';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(isTipDismissedProvider(_tipId));
    if (dismissed) return const SizedBox.shrink();
    return _Banner(
      onTap: () {
        // Send the user to the new scalp lesson. The next 3 lessons in
        // the same section cover theta-math, stop discipline, and
        // when-to-skip so the tap kicks off the full scalp onboarding.
        context.go(
          RoutePaths.lessonsLessonFor('execution', 'scalp-what-is-it'),
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
                      text: "What's new in v2.5 — ",
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text:
                          '0DTE Scalp mode (opt-in) with theta-per-minute, 10-min TTL, and a dedicated Scanner + Hot Trades tab. Tap to learn.',
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
