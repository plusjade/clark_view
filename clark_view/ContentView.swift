import SwiftUI

/// Home is this device's joined feeds, with diagnostics in the menu.
struct ContentView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(LiveActivityCoordinator.self) private var liveActivities
    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptions = SubscriptionStore()
    @State private var diagnosticsPanel: DiagnosticsPanel?

    var body: some View {
        @Bindable var deepLinks = deepLinks

        NavigationStack {
            SubscriptionListView(openNotifications: { diagnosticsPanel = .notifications })
                .navigationTitle("Your feeds")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        DiagnosticsMenu(selection: $diagnosticsPanel)
                    }
                }
                .diagnosticsPanel($diagnosticsPanel)
                .onChange(of: diagnosticsPanel) { previous, _ in
                    // Notification setup changes the delivery note under the subscriptions.
                    if previous == .notifications { Task { await subscriptions.load() } }
                }
                .navigationDestination(item: $deepLinks.destination) { destination in
                    DeepLinkDetailView(destination: destination)
                }
                .onOpenURL { deepLinks.open($0) }
                .task { await refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await refresh() } }
                }
        }
        .environment(subscriptions)
    }

    private func refresh() async {
        // Loading registers a first-run install, which the inventory report requires.
        Task {
            await subscriptions.load()
            await WidgetInventoryReporter.shared.report(trigger: .appActivation)
        }
        await liveActivities.refresh()
        await notifications.refresh()
    }
}

#Preview {
    ContentView()
        .environment(NotificationSettings())
        .environment(DeepLinkRouter())
        .environment(LiveActivityCoordinator())
}
