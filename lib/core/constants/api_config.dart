/// Base URL for the Boyce Armory backend API.
///
/// Resolution order:
///   1. `--dart-define=API_BASE_URL=https://...` if passed at build time.
///   2. Otherwise: the production URL on Render.
///
/// We point ALL builds (debug + release) at the live Render backend by
/// default. That way `flutter run` from a fresh checkout "just works"
/// without anyone needing a local backend running on their laptop.
///
/// If you want to point at a local backend for development, run with:
///   Android emulator:  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///   iOS simulator:     flutter run --dart-define=API_BASE_URL=http://localhost:8080
///   Real device:       flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:8080
///
/// To point at a custom domain in prod, edit `_prodUrl` below or override at
/// build time:
///   flutter build apk --release --dart-define=API_BASE_URL=https://api.boycearmory.com
class ApiConfig {
  ApiConfig._();

  /// Production fallback. Edit this line if you move off the default Render
  /// subdomain (e.g. to a custom domain like api.boycearmory.com).
  static const String _prodUrl = 'https://boyce-armory-backend.onrender.com';

  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return _prodUrl;
  }

  static const Duration timeout = Duration(seconds: 15);
}
