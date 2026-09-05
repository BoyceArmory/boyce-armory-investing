import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized analytics for product decisions.
///
/// Wraps Firebase Analytics so call sites stay clean and the schema of
/// event names lives in one file. All methods are no-ops in debug builds
/// to keep dev usage out of the dashboard. We deliberately keep the event
/// vocabulary small — explicit events for the moments that drive product
/// decisions (alert opened, alert action, watchlist add, etc.), not
/// random impressions.
class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  static NavigatorObserver? _observer;

  /// Observer instance for go_router / Navigator screen tracking.
  ///
  /// Sep 2026 fix: this used to be a plain `static final` field initialized
  /// straight to `FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.
  /// instance)`. `FirebaseAnalytics.instance` calls `Firebase.app()`
  /// internally, which throws if `Firebase.initializeApp()` hasn't
  /// resolved yet. Since `appRouterProvider` reads this field as soon as
  /// `BoyceArmoryApp.build()` runs (see app.dart, first line of build),
  /// that throw took down the entire app the moment Firebase wasn't ready
  /// — including in the widget-test smoke test, which the test file's own
  /// header comment says was deliberately written to NOT require Firebase.
  /// Guarding on `Firebase.apps.isEmpty` and falling back to a no-op
  /// observer fixes both the test and the (admittedly rarer) production
  /// case of a frame rendering before Firebase.initializeApp() resolves.
  static NavigatorObserver get observer {
    if (_observer != null) return _observer!;
    if (Firebase.apps.isEmpty) {
      return _NoopNavigatorObserver();
    }
    final NavigatorObserver o = FirebaseAnalyticsObserver(analytics: _fa);
    _observer = o;
    return o;
  }

  static bool get _enabled => !kDebugMode && Firebase.apps.isNotEmpty;

  // ---- User identity ----

  static Future<void> setUserId(String? uid) async {
    if (!_enabled) return;
    await _fa.setUserId(id: uid);
  }

  static Future<void> setUserTier(String tier) async {
    if (!_enabled) return;
    await _fa.setUserProperty(name: 'tier', value: tier);
  }

  // ---- Scanner alert engagement ----

  static Future<void> alertOpened({
    required String alertId,
    required String mode,
    required String kind,
    required String grade,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'alert_opened',
      parameters: <String, Object>{
        'alert_id': alertId,
        'mode': mode,
        'kind': kind,
        'grade': grade,
      },
    );
  }

  /// Fires when a user explicitly marks how they engaged with an alert:
  /// took the trade, watching it, or skipped. Used for real-trade attribution.
  static Future<void> alertActioned({
    required String alertId,
    required String action, // "took" | "watching" | "pass"
    required String grade,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'alert_actioned',
      parameters: <String, Object>{
        'alert_id': alertId,
        'action': action,
        'grade': grade,
      },
    );
  }

  // ---- Watchlist ----

  static Future<void> watchlistAdded(String symbol) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'watchlist_added',
      parameters: <String, Object>{'symbol': symbol},
    );
  }

  static Future<void> watchlistRemoved(String symbol) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'watchlist_removed',
      parameters: <String, Object>{'symbol': symbol},
    );
  }

  // ---- Track record / performance ----

  static Future<void> trackRecordViewed({required int windowDays}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'track_record_viewed',
      parameters: <String, Object>{'window_days': windowDays},
    );
  }

  // ---- Notifications ----

  static Future<void> notificationsEnabled() async {
    if (!_enabled) return;
    await _fa.logEvent(name: 'notifications_enabled');
  }

  static Future<void> notificationsDenied() async {
    if (!_enabled) return;
    await _fa.logEvent(name: 'notifications_denied');
  }

  // ---- Charts ----

  static Future<void> chartOpened({
    required String symbol,
    required String timeframe,
  }) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'chart_opened',
      parameters: <String, Object>{
        'symbol': symbol,
        'timeframe': timeframe,
      },
    );
  }

  // ---- Onboarding / activation ----

  static Future<void> signedUp({required String method}) async {
    if (!_enabled) return;
    await _fa.logEvent(
      name: 'signed_up',
      parameters: <String, Object>{'method': method},
    );
  }
}

/// Lightweight provider so screens can call analytics via Riverpod when
/// they prefer dependency injection over the static helper.
final Provider<AnalyticsService> analyticsProvider =
    Provider<AnalyticsService>((Ref ref) => AnalyticsService._());

/// Does nothing. Used by [AnalyticsService.observer] before Firebase has
/// initialized (widget tests, or a very early frame in production) so
/// go_router always has a valid observer to attach without touching
/// Firebase at all.
class _NoopNavigatorObserver extends NavigatorObserver {}
