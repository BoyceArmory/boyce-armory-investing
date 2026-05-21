import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Base URL for the Boyce Armory backend API.
///
/// Different defaults per platform because Android emulator and iOS simulator
/// reach the host machine through different addresses:
///   - Android emulator -> 10.0.2.2 maps to your host's localhost
///   - iOS simulator    -> can use localhost directly
///   - Real device      -> use your machine's LAN IP or a deployed host
///
/// Override at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.boycearmory.io
class ApiConfig {
  ApiConfig._();

  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:8080';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    } catch (_) {
      // Platform isn't available on web; fall through.
    }
    return 'http://localhost:8080';
  }

  static const Duration timeout = Duration(seconds: 15);
}
