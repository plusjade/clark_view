import SwiftUI
import WidgetKit

/// Coordinates setup; permission and diagnostic screens own their respective controls.
struct ContentView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPaired = DeviceIdentity.isPaired
    @State private var showsDiagnostics = false

    var body: some View {
        NavigationStack {
            Group {
                if isPaired {
                    NotificationSettingsView()
                } else {
                    PairingView(onPaired: { isPaired = true })
                }
            }
            .navigationTitle("Clark View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Diagnostics", systemImage: "stethoscope") {
                        showsDiagnostics = true
                    }
                }
            }
            .sheet(isPresented: $showsDiagnostics) {
                NavigationStack {
                    DiagnosticsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showsDiagnostics = false }
                            }
                        }
                }
            }
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
        }
    }

    private func refresh() async {
        await notifications.refresh()
        // A failed fetch must not erase pairing; a lost pairing response can be recovered here.
        let pairingAtStart = isPaired
        guard let status = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID),
              isPaired == pairingAtStart else { return }
        DeviceIdentity.isPaired = status.paired
        isPaired = status.paired
        if status.paired && !pairingAtStart {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
        }
    }
}

#Preview {
    ContentView()
        .environment(NotificationSettings())
}
