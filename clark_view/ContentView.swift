import SwiftUI
import WidgetKit

/// Pairing takes precedence; a paired install opens its live feed.
struct ContentView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(LiveActivityCoordinator.self) private var liveActivities
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPaired = DeviceIdentity.isPaired
    @State private var diagnosticsPanel: DiagnosticsPanel?

    var body: some View {
        @Bindable var deepLinks = deepLinks

        NavigationStack {
            Group {
                if isPaired {
                    FeedHomeView()
                } else {
                    PairingView(onPaired: { isPaired = true })
                }
            }
            .navigationTitle("Clark View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    DiagnosticsMenu(selection: $diagnosticsPanel)
                }
            }
            .diagnosticsPanel($diagnosticsPanel)
            .navigationDestination(item: $deepLinks.destination) { destination in
                DeepLinkDetailView(destination: destination)
            }
            .onOpenURL { deepLinks.open($0) }
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refresh() } }
            }
        }
    }

    private func refresh() async {
        await liveActivities.refresh()
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
        .environment(DeepLinkRouter())
        .environment(LiveActivityCoordinator())
}
