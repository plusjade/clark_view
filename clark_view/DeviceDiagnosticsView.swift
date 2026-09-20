import SwiftUI

/// Registration identity and the sources the server has assigned to this device.
struct DeviceDiagnosticsView: View {
    @State private var status: DeviceStatusClient.DeviceStatus?
    @State private var isLoading = false

    var body: some View {
        Form {
            Section("Registration") {
                if let status {
                    DiagnosticRow("Device ID", status.deviceId)
                    DiagnosticRow("Device Name", status.name ?? "—")
                    DiagnosticRow("Paired", status.paired ? "Yes" : "No")
                } else if isLoading {
                    ProgressView()
                } else {
                    Text("Couldn’t load status").foregroundStyle(.secondary)
                }
            }

            if let status {
                Section("Assigned Sources") {
                    if let sources = status.sources {
                        if sources.isEmpty {
                            Text("No sources assigned. Add a source in the browser to populate the widget.")
                                .foregroundStyle(.secondary)
                        } else {
                            // Kind is metadata, not unique identity; preserve each association in response order.
                            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                                Text(source.kind)
                            }
                        }
                    } else {
                        Text(status.paired ? "Source associations unavailable." : "Pair this device to assign sources.")
                            .foregroundStyle(.secondary)
                    }
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
