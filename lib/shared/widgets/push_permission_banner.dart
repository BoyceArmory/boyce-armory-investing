import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/data/snooze_service.dart';

/// Polls the OS notification permission and renders nothing while it's
/// granted. When the user has revoked permission (and their master pref
/// is still on, meaning they DO want pushes), shows a red banner with a
/// "Open Settings" button that deep-links to the app's iOS settings page.
///
/// Why this matters: lots of users grant permission on first launch,
/// later toggle "Notifications" off at the OS level, and then wonder
/// why the scanner isn't pinging. Without this banner the only diagnosis
/// is "Send test push to me" in Settings — which they won't try.
class PushPermissionBanner extends ConsumerStatefulWidget {
  const PushPermissionBanner({super.key});

  @override
  ConsumerState<PushPermissionBanner> createState() =>
      _PushPermissionBannerState();
}

class _PushPermissionBannerState extends ConsumerState<PushPermissionBanner>
    with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _probe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-probe when the user comes back from system Settings so the
    // banner disappears immediately if they flipped permission on.
    if (state == AppLifecycleState.resumed) _probe();
  }

  Future<void> _probe() async {
    final ok =
        await ref.read(messagingServiceProvider).isPushPermissionGranted();
    if (mounted) setState(() => _granted = ok);
  }

  Future<void> _openSettings() async {
    // iOS deep-link to the app's preferences pane. On Android this URL
    // is a no-op and the user has to navigate manually — acceptable
    // tradeoff vs adding a platform-channel dependency.
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_granted == null || _granted == true) {
      return const SizedBox.shrink();
    }
    // Don't yell at users who explicitly want silence — if master is off
    // they made the call. Banner is for the "permission revoked OUTSIDE
    // the app" case where intent and state disagree.
    final masterOn = ref
        .watch(masterNotifProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);
    if (!masterOn) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.bearish.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bearish.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.notifications_off,
              color: AppColors.bearish, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Push notifications are blocked',
                  style: TextStyle(
                    color: AppColors.bearish,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your app preferences say ON but iOS has blocked pushes. Open Settings to re-enable.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bearish,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
