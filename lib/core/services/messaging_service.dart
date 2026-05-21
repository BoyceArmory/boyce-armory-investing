import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Firebase Cloud Messaging service.
///
/// - Requests notification permission.
/// - Fetches the device FCM token.
/// - Registers it with Firestore under `device_tokens/{token}` so the backend
///   can fan out push notifications.
/// - Listens for token refreshes.
class MessagingService {
  MessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  /// Returns the FCM token if granted, otherwise null.
  Future<String?> initForUser(String uid) async {
    try {
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
      _messaging.onTokenRefresh.listen((String t) {
        _persistToken(uid: uid, token: t);
      });
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        if (kDebugMode) {
          debugPrint('FCM foreground: ${msg.notification?.title}');
        }
      });
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
