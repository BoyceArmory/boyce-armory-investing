import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/auth_state_provider.dart';
import 'core/providers/service_providers.dart';
import 'core/routing/app_router.dart';
import 'core/routing/route_paths.dart';
import 'core/theme/app_theme.dart';

/// Top-level app widget. Holds the router and theme. Side-effects that should
/// run once (FCM registration on sign-in) live here so they aren't tied to
/// any single screen's lifecycle.
class BoyceArmoryApp extends ConsumerStatefulWidget {
  const BoyceArmoryApp({super.key});

  @override
  ConsumerState<BoyceArmoryApp> createState() => _BoyceArmoryAppState();
}

class _BoyceArmoryAppState extends ConsumerState<BoyceArmoryApp> {
  String? _fcmRegisteredForUid;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF050608),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  /// Route a tapped push notification into the right screen.
  ///
  /// Inspects `data.kind` to decide:
  ///   - `chat_broadcast` → /chat/{roomId} (ADMIN BUYS, etc.)
  ///   - `scanner_alert`  → /scanner (existing behavior — pre-existing pushes)
  ///   - anything else    → no-op (lets the app render whatever screen it
  ///                        was already showing)
  ///
  /// Safe across hot-reload because [GoRouter] tolerates being asked to go
  /// to a route while already on it.
  void _handleNotificationTap(GoRouter router, RemoteMessage msg) {
    final Map<String, dynamic> data = msg.data;
    final String kind = (data['kind'] ?? '').toString();
    switch (kind) {
      case 'chat_broadcast':
        final String roomId = (data['roomId'] ?? '').toString();
        if (roomId.isNotEmpty) {
          router.go(RoutePaths.chatRoomFor(roomId));
        }
        break;
      case 'scanner_alert':
        router.go(RoutePaths.scanner);
        break;
      default:
        // Unknown kind: do nothing, leave the user wherever they were.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);

    // Register the device's FCM token when a user signs in, and reset on sign-out.
    ref.listen(currentFirebaseUserProvider, (_, user) {
      if (user == null) {
        _fcmRegisteredForUid = null;
        return;
      }
      if (_fcmRegisteredForUid == user.uid) return;
      _fcmRegisteredForUid = user.uid;
      final messaging = ref.read(messagingServiceProvider);
      // Configure tap handler BEFORE initForUser so cold-start taps land
      // on the right route (initForUser checks getInitialMessage()).
      messaging.setTapHandler((RemoteMessage msg) {
        _handleNotificationTap(router, msg);
      });
      messaging.initForUser(user.uid);
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
