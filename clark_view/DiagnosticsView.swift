import SwiftUI
import UIKit
import WidgetKit

/// Operational controls stay behind the diagnostics entry point.
struct DiagnosticsView: View {
    @Environment(NotificationSettings.self) private var notifications
    @State private var status: DeviceStatusClient.DeviceStatus?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Device") {
                if let status {
                    row("Device ID", status.deviceId)
                    row("Device Name", status.name ?? "—")
                    row("Paired", status.paired ? "Yes" : "No")
                } else if isLoading {
                    ProgressView()
                } else {
                    Text("Couldn’t load status").foregroundStyle(.secondary)
                }
                Button("Refresh Status") { Task { await refresh() } }
                    .disabled(isLoading)
            }

            if let status {
                Section("Assigned Sources") {
                    if let sources = status.sources {
                        if sources.isEmpty {
                            Text("No sources assigned. Add a source in the browser to populate the widget.")
                                .foregroundStyle(.secondary)
                        } else {
                            row("Count", String(sources.count))
                            // Kind is metadata, not unique identity; preserve each association in response order.
                            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                                DisclosureGroup(source.kind) {
                                    Text(source.settingsDescription)
                                        .font(.system(.footnote, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .accessibilityLabel("Settings: " + source.settingsDescription)
                                }
                            }
                        }
                    } else {
                        Text(status.paired ? "Source associations unavailable." : "Pair this device to assign sources.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Widget") {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let refresh = WidgetRefreshDiagnostics.snapshot
                    row("Widget Push", PushTokenClient.registrationStatus)
                    row("Requested", displayDate(refresh.lastRequestedAt))
                    row("Last Attempt", displayDate(refresh.lastAttemptedAt))
                    row("Last Success", displayDate(refresh.lastSucceededAt))
                    row("Last Result", refresh.resultDescription)
                }
                Button("Request Widget Refresh", systemImage: "arrow.clockwise") {
                    WidgetRefreshDiagnostics.recordManualRequest()
                    WidgetFocusStore.requireNetworkRefresh()
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
                }
            }

            Section("Notifications") {
                row("Apple Registration", notifications.registrationStatus)
                row("Server Sync", notifications.serverStatus)
                if let token = notifications.token {
                    Button("Copy APNs Token") { UIPasteboard.general.string = token }
                    Button("Send Test Notification") { Task { await notifications.sendTest() } }
                        .disabled(notifications.isSendingTest || !notifications.allowsAlerts)
                }
                if let error = notifications.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                Button("Retry Registration") { Task { await notifications.refresh() } }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        status = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID)
    }

    private func displayDate(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "—"
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
