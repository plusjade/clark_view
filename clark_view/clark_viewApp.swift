//
//  clark_viewApp.swift
//  clark_view
//
//  Created by Jade Dominguez on 8/18/26.
//

import SwiftUI

@main
struct clark_viewApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(notificationDelegate.notifications)
        }
    }
}
