//
//  AppDelegate.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/28/26.
//

import UIKit
import WidgetKit

/// Only reason this exists: SwiftUI's `App` protocol has no hook for the
/// UIKit remote-notification callbacks below. Registers for silent push on
/// launch (regardless of pairing state — see `PushTokenClient`) and reloads
/// the widget timeline when the server signals a config change.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            await PushTokenClient.upload(device: DeviceIdentity.deviceID, token: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No fallback needed: WidgetKit's own timeline policy (see Provider in
        // ClarkViewWidget.swift) still refreshes on its own schedule — push
        // only shortens that wait, it's never the only path to fresh data.
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
        completionHandler(.newData)
    }
}
