import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/auth_state_provider.dart';
import 'core/providers/service_providers.dart';
import 'core/routing/app_router.dart';
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

  @override
  Widget build(BuildContext context) {
    // Register the device's FCM token when a user signs in, and reset on sign-out.
    ref.listen(currentFirebaseUserProvider, (_, user) {
      if (user == null) {
        _fcmRegisteredForUid = null;
        return;
      }
      if (_fcmRegisteredForUid == user.uid) return;
      _fcmRegisteredForUid = user.uid;
      ref.read(messagingServiceProvider).initForUser(user.uid);
    });

    final GoRouter router = ref.watch(appRouterProvider);
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
