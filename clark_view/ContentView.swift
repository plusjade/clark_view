import SwiftUI

/// Home is this device's joined feeds, with a separate diagnostics hub.
struct ContentView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(LiveActivityCoordinator.self) private var liveActivities
    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptions = SubscriptionStore()
    @State private var showsDiagnostics = false
    @State private var initialDiagnosticsPanel: DiagnosticsPanel?

    var body: some View {
        @Bindable var deepLinks = deepLinks

        NavigationStack {
            SubscriptionListView(openNotifications: {
                initialDiagnosticsPanel = .notifications
                showsDiagnostics = true
            })
                .navigationTitle("Your feeds")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Diagnostics", systemImage: "stethoscope") {
                            initialDiagnosticsPanel = nil
                            showsDiagnostics = true
                        }
                    }
                }
                .sheet(isPresented: $showsDiagnostics, onDismiss: {
                    // Notification setup can change the delivery note under the subscriptions.
                    Task { await subscriptions.load() }
                }, content: {
                    DiagnosticsView(initialPanel: initialDiagnosticsPanel)
                })
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
