import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// One-time Firebase bootstrap. Call from main() before runApp.
class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Firebase init failed: $e\n$st');
      }
      rethrow;
    }
  }

  static bool get isReady => _initialized;
}
