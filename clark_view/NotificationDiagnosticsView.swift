import SwiftUI
import UIKit

/// Alert-push instrumentation, reached from notification setup in the menu.
struct NotificationDiagnosticsView: View {
    @Environment(NotificationSettings.self) private var notifications

    var body: some View {
        Form {
            Section("Delivery") {
                DiagnosticRow("Permission", notifications.allowsAlerts ? "Allowed" : "Not allowed")
                DiagnosticRow("Apple Registration", notifications.registrationStatus)
                DiagnosticRow("Server Sync", notifications.serverStatus)
                if let error = notifications.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                if let token = notifications.token {
                    Button("Copy APNs Token") { UIPasteboard.general.string = token }
                    Button("Send Test Notification") { Task { await notifications.sendTest() } }
                        .disabled(notifications.isSendingTest || !notifications.allowsAlerts)
                }
                Button("Retry Registration") { Task { await notifications.refresh() } }
            } footer: {
                Text("The containing app and the widget extension register separate APNs tokens.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refresh() }
    }
}
