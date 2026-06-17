import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Signature for the tap handler the app supplies. Called when:
///   - User taps a notification while the app is backgrounded
///     (FirebaseMessaging.onMessageOpenedApp).
///   - User taps a notification that cold-started the app
///     (FirebaseMessaging.instance.getInitialMessage()).
///
/// The handler should inspect `message.data['kind']` and route accordingly.
typedef PushTapHandler = void Function(RemoteMessage message);

/// Firebase Cloud Messaging service.
///
/// - Requests notification permission.
/// - Fetches the device FCM token.
/// - Registers it with Firestore under `device_tokens/{token}` so the backend
///   can fan out push notifications.
/// - Listens for token refreshes.
/// - Routes notification taps through the supplied [PushTapHandler] so the
///   app can deep-link into the right screen (e.g. ADMIN BUYS chat room).
class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  /// Tap handler the host widget can swap in. We set it from app.dart once
  /// the router is available so this service stays UI-agnostic.
  PushTapHandler? _onTap;

  /// Tracks which uid the foreground/token-refresh listeners are currently
  /// attached for. Stored so account switches deactivate the previous
  /// subscriptions instead of stacking new ones on top - the leak that
  /// caused notification taps to navigate the router N times after N
  /// account switches.
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _coldStartHandled = false;

  /// Configure the notification-tap handler. Safe to call multiple times —
  /// the most recent handler wins. Called from app.dart once GoRouter is
  /// available so the service stays UI-agnostic.
  void setTapHandler(PushTapHandler handler) {
    _onTap = handler;
  }

  /// Returns the FCM token if granted, otherwise null.
  ///
  /// Idempotent across account switches: cancels any previous
  /// subscriptions before attaching new ones. Without this, signing
  /// out and back in (or switching accounts) doubled every FCM
  /// listener, so a single push tap would call the router N times
  /// after N sign-in cycles.
  /// Returns true if the OS-level notification permission is currently
  /// granted (authorized or provisional). False if denied or not
  /// determined. Cheap — no request prompt, just an inspection of the
  /// current state. Used by the home-screen banner to surface a re-
  /// prompt when the user has revoked permission post-install.
  Future<bool> isPushPermissionGranted() async {
    try {
      final s = await _messaging.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      // If FCM isn't initialised yet (shouldn't happen post-bootstrap)
      // treat permission as unknown-good so we don't spam users with a
      // banner during a transient probe failure.
      return true;
    }
  }

  Future<String?> initForUser(String uid) async {
    try {
      // Cancel any subscriptions from a previous user. Each is
      // recreated below with the new uid baked into _persistToken.
      await _tokenRefreshSub?.cancel();
      await _foregroundSub?.cancel();
      await _openedSub?.cancel();
      _tokenRefreshSub = null;
      _foregroundSub = null;
      _openedSub = null;

      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      final String? token = await _messaging.getToken();
      if (token != null) {
        await _persistToken(uid: uid, token: token);
      }
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((String t) {
        _persistToken(uid: uid, token: t);
      });
      _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        if (kDebugMode) {
          debugPrint('FCM foreground: ${msg.notification?.title}');
        }
      });

      // Tap-while-running: app is open in background, user taps notification.
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        if (kDebugMode) {
          debugPrint('FCM tap (running): ${msg.data}');
        }
        _onTap?.call(msg);
      });

      // Cold-start: app was killed, user tapped notification to launch it.
      // getInitialMessage() resolves once; null if app was started normally.
      // Only handle it the first time initForUser runs - if the user signs
      // out and back in, the cold-start message is still the original one
      // and re-firing the tap handler would navigate them somewhere
      // unexpected mid-session.
      if (!_coldStartHandled) {
        _coldStartHandled = true;
        final RemoteMessage? initial = await _messaging.getInitialMessage();
        if (initial != null) {
          if (kDebugMode) {
            debugPrint('FCM tap (cold start): ${initial.data}');
          }
          // Defer slightly so the router/Navigator is mounted before we navigate.
          Future<void>.delayed(const Duration(milliseconds: 400)).then((_) {
            _onTap?.call(initial);
          });
        }
      }

      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('Messaging init failed: $e');
      return null;
    }
  }

  Future<void> _persistToken({required String uid, required String token}) {
    return _db
        .collection(FirestoreCollections.deviceTokens)
        .doc(token)
        .set({
      'token': token,
      'uid': uid,
      'active': true,
      'platform': defaultTargetPlatform.name,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> deactivate(String token) {
    return _db
        .collection(FirestoreCollections.deviceTokens)
        .doc(token)
        .set({
      'active': false,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
