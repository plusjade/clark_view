import SwiftUI

/// Registration identity diagnostics for this installation.
struct DeviceDiagnosticsView: View {
    @State private var status: DeviceStatusClient.DeviceStatus?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Registration") {
                if let status {
                    DiagnosticRow("Device ID", status.deviceId)
                    DiagnosticRow("Device Name", status.name ?? "—")
                    DiagnosticRow("Registered", status.registered ? "Yes" : "No")
                } else if isLoading {
                    ProgressView()
                } else {
                    Text("Couldn’t load status").foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Refresh Status") { Task { await refresh() } }
                    .disabled(isLoading)
            }
        }
        .navigationTitle("Device")
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
}
