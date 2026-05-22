import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// AppDelegate for Boyce Armory.
//
// What this file is responsible for:
//   1. Booting the Firebase iOS SDK (FirebaseApp.configure) before any
//      Firebase-touching Flutter plugin tries to call into it. This MUST
//      run before the Flutter engine starts handing off to plugin code.
//   2. Registering with APNs for remote notifications and wiring FCM to
//      receive them.
//   3. Handing the APNs device token to FCM so the firebase_messaging
//      plugin can return a real FCM token to Dart.
//
// The MessagingService on the Dart side handles permission requests,
// token persistence to Firestore, and onMessage subscriptions. This
// file just makes sure the native plumbing is in place.
@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Boot Firebase as early as possible.
    FirebaseApp.configure()

    // Become the FCM delegate so we get token + remote-message callbacks.
    Messaging.messaging().delegate = self

    // Become the notification center delegate so foreground notifications
    // show as banners (otherwise iOS suppresses them while the app is open).
    UNUserNotificationCenter.current().delegate = self

    // Register with APNs. The actual permission prompt is owned by the Dart
    // MessagingService.initForUser flow; this call just kicks off the
    // device-token handshake so FCM has something to bind to.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Required for the Flutter plugin registrant on the implicit-engine path.
  override func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // ---- APNs -> FCM token bridge -------------------------------------------

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Hand the APNs token to FCM. Without this, Messaging.messaging().token
    // will hang forever waiting for a token, especially in production.
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs registration failed: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // ---- FCM token refresh ---------------------------------------------------

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    // No-op on the native side. firebase_messaging surfaces this to Dart via
    // its own listener, where MessagingService persists the token to
    // device_tokens/{token}.
  }

  // ---- Foreground notification presentation --------------------------------

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner + sound + badge even when the app is foregrounded so users
    // don't miss alerts while looking at the app.
    completionHandler([.banner, .sound, .badge])
  }
}
