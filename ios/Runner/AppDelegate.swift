import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications show alerts while the app is open.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // Workmanager's background isolate needs the plugins (sqflite, prefs...).
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // Same id as _syncTaskName in offline_sync_manager.dart and
    // BGTaskSchedulerPermittedIdentifiers in Info.plist.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "shuledrive_background_sync",
      frequency: NSNumber(value: 15 * 60)
    )

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
