import UIKit
import Flutter
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // v3 push (2026-11-22): v3 iPhone builds never got an APNs token, so
    // Firebase could not make a push token ("No APNs token from Apple.").
    // Ask Apple for the device token here ourselves instead of relying on the
    // plugin's launch hook (Flutter 3.47 builds run with a scene delegate).
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Hand Apple's device token straight to Firebase Messaging (the Firebase
  // app delegate proxy is off in Info.plist), then let plugins see it too.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Keep the reason if Apple refuses (read by setFCMToken through
  // shared_preferences, hence the "flutter." prefix).
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    UserDefaults.standard.set(error.localizedDescription, forKey: "flutter.cs_apns_error")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
