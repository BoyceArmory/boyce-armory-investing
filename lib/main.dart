import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/firebase_service.dart';

Future<void> main() async {
  // Use runZonedGuarded so any uncaught async error in the entire app
  // is captured by Crashlytics. The non-async FlutterError handler
  // also forwards into Crashlytics — together they catch ~everything.
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
      ]);
      await FirebaseService.init();

      // Crashlytics wiring. We disable collection in debug builds so
      // every hot-reload doesn't pollute the dashboard with dev noise.
      final FirebaseCrashlytics crash = FirebaseCrashlytics.instance;
      await crash.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Flutter framework errors (widget build, layout, paint) go here.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        crash.recordFlutterFatalError(details);
      };

      // Platform-level errors that escape the Flutter framework. Returns
      // true so Flutter doesn't ALSO crash the isolate after we logged it.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        crash.recordError(error, stack, fatal: true);
        return true;
      };

      runApp(const ProviderScope(child: BoyceArmoryApp()));
    },
    (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
