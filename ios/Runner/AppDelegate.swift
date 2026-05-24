import UIKit
import Flutter
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // NOTE: Do NOT call FirebaseApp.configure() here.
    // Firebase init happens in Dart via main.dart → FirebaseService.init() →
    // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).
    // Calling configure() here too would either:
    //   (a) crash with "FirebaseApp.configure() has already been called", or
    //   (b) require GoogleService-Info.plist to be registered as a Bundle
    //       Resource in the Xcode project (which currently it is not).
    // Setting the APNs token below works because the device-token callback
    // arrives asynchronously, by which time Dart has already initialized
    // Firebase.

    UNUserNotificationCenter.current().delegate = self

    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken

    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}