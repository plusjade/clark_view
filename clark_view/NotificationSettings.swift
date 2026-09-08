import SwiftUI
import UIKit
import UserNotifications

/// Owns visible-notification permission and the containing app's APNs registration.
/// WidgetKit registers its separate token in the widget extension.
@MainActor
@Observable
final class NotificationSettings {
    var authorization: UNAuthorizationStatus = .notDetermined
    var token: String?
    var registrationStatus = "Not registered"
    var errorMessage: String?
    var serverStatus = "Not synced with server"
    var isSendingTest = false
    private var syncTask: Task<Void, Never>?

    var allowsAlerts: Bool {
        authorization == .authorized || authorization == .provisional || authorization == .ephemeral
    }

    func synchronize() {
        let previous = syncTask
        syncTask = Task {
            await previous?.value
            guard let token else { return }
            do {
                serverStatus = try await AlertPushClient.send(token: token, allowed: allowsAlerts)
                errorMessage = nil
            } catch {
                serverStatus = "Server sync failed; retry or reopen the app"
                errorMessage = error.localizedDescription
            }
        }
    }

    func sendTest() async {
        guard let token, allowsAlerts, !isSendingTest else { return }
        isSendingTest = true
        defer { isSendingTest = false }
        await syncTask?.value
        do {
            serverStatus = try await AlertPushClient.send(token: token, allowed: true, test: true)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorization = settings.authorizationStatus
        if authorization != .notDetermined {
            if token == nil { registrationStatus = "Registering with Apple…" }
            UIApplication.shared.registerForRemoteNotifications()
            synchronize()
        }
    }

    func enable() async {
        errorMessage = nil
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refresh()
        } catch {
            errorMessage = "Couldn't request notification permission. Please try again."
        }
    }
}

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let notifications = NotificationSettings()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notifications.token = deviceToken.map { String(format: "%02x", $0) }.joined()
        notifications.registrationStatus = "Registered with Apple"
        notifications.errorMessage = nil
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notifications.authorization = settings.authorizationStatus
            notifications.synchronize()
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notifications.token = nil
        notifications.registrationStatus = "Registration failed"
        notifications.errorMessage = error.localizedDescription
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

struct NotificationSettingsView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications").font(.headline)
            if notifications.authorization == .notDetermined {
                Text("Allow Clark View to show alerts and play sounds.")
                Button("Enable Notifications") { Task { await notifications.enable() } }
            } else {
                Text(notifications.authorization == .denied ? "Notifications are off" : "Notifications are allowed")
                Button("Notification Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            }
            if notifications.authorization != .denied {
                Text(notifications.registrationStatus).font(.footnote).foregroundStyle(.secondary)
                if let token = notifications.token {
                    Button("Copy APNs Token for Testing") { UIPasteboard.general.string = token }
                        .font(.footnote)
                    Button("Send Test Notification") { Task { await notifications.sendTest() } }
                        .disabled(notifications.isSendingTest || !notifications.allowsAlerts)
                    Text(notifications.serverStatus)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let error = notifications.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
                Button("Retry Registration") { Task { await notifications.refresh() } }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await notifications.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notifications.refresh() } }
        }
    }
}
