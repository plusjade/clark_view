import SwiftUI
import UIKit

/// Notification setup lives in the app menu.
struct NotificationSettingsView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: notifications.allowsAlerts ? "bell.badge.fill" : "bell")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(notifications.allowsAlerts ? "You’re all set" : "Enable notifications")
                        .font(.title2.bold())
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                if notifications.authorization == .notDetermined {
                    Button {
                        isRequesting = true
                        Task {
                            await notifications.enable()
                            isRequesting = false
                        }
                    } label: {
                        HStack {
                            if isRequesting { ProgressView() }
                            Text("Enable Notifications")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)
                } else {
                    Button("Open Notification Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if notifications.authorization == .notDetermined, let error = notifications.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }

                Text("Add the Clark View widget to your Home Screen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                NavigationLink("Notification Diagnostics") {
                    NotificationDiagnosticsView()
                }
            }
            .frame(maxWidth: 420)
            .padding(24)
            .padding(.top, 40)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var message: String {
        if notifications.allowsAlerts {
            return "Notifications are enabled on this device."
        }
        if notifications.authorization == .denied {
            return "Notifications are off. You can enable alerts and sounds in Settings."
        }
        return "Allow Clark View to send alerts and play sounds. You can change this anytime in Settings."
    }
}
