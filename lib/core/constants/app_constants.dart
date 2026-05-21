/// Application-wide constants. Keep small and stable - feature-specific
/// constants belong with their feature.
class AppConstants {
  AppConstants._();

  static const String appName = 'Boyce Armory';
  static const String appTagline = 'Premium options intelligence.';

  // Defaults
  static const Duration defaultAnimationDuration = Duration(milliseconds: 280);
  static const Duration longAnimationDuration = Duration(milliseconds: 450);
}

/// Firestore collection names - mirror the backend exactly.
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String scannerResults = 'scanner_results'; // admin-only
  static const String scannerAlerts = 'scanner_alerts';   // public
  static const String tradeAlerts = 'trade_alerts';
  static const String activeTrades = 'active_trades';
  static const String closedTrades = 'closed_trades';
  static const String performanceStats = 'performance_stats';
  static const String dailyRecaps = 'daily_recaps';
  static const String notifications = 'notifications';
  static const String deviceTokens = 'device_tokens';
}
