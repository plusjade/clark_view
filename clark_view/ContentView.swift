import SwiftUI

/// Home is this device's joined feeds, with a separate diagnostics hub.
struct ContentView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(LiveActivityCoordinator.self) private var liveActivities
    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptions = SubscriptionStore()
    @State private var showsDiagnostics = false
    @State private var defersEventPresentation = false
    @State private var initialDiagnosticsPanel: DiagnosticsPanel?

    var body: some View {
        @Bindable var deepLinks = deepLinks
        let eventDestination = Binding<AppDeepLink?>(
            get: {
                guard !showsDiagnostics, !defersEventPresentation else { return nil }
                return deepLinks.destination?.kind == .event ? deepLinks.destination : nil
            },
            set: { destination in
                if let destination {
                    deepLinks.destination = destination
                } else if deepLinks.destination?.kind == .event {
                    deepLinks.destination = nil
                }
            }
        )
        let navigationDestination = Binding<AppDeepLink?>(
            get: {
                deepLinks.destination?.kind == .event ? nil : deepLinks.destination
            },
            set: { destination in
                if let destination {
                    deepLinks.destination = destination
                } else if deepLinks.destination?.kind != .event {
                    deepLinks.destination = nil
                }
            }
        )

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
                    // Wait for the diagnostics dismissal to finish before presenting a pending event.
                    defersEventPresentation = false
                    // Notification setup can change the delivery note under the subscriptions.
                    Task { await subscriptions.load() }
                }, content: {
                    DiagnosticsView(initialPanel: initialDiagnosticsPanel)
                })
                .navigationDestination(item: navigationDestination) { destination in
                    DeepLinkDetailView(destination: destination)
                }
                .fullScreenCover(item: eventDestination) { destination in
                    NavigationStack {
                        DeepLinkDetailView(destination: destination, showsCloseButton: true)
                    }
                }
                .onOpenURL { deepLinks.open($0) }
                .onChange(of: deepLinks.destination) { _, destination in
                    guard destination?.kind == .event, showsDiagnostics else { return }
                    defersEventPresentation = true
                    showsDiagnostics = false
                }
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
