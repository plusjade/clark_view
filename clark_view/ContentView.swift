import SwiftUI

/// Feed selection is independent of pairing; pairing remains available for notifications.
struct ContentView: View {
    @Environment(NotificationSettings.self) private var notifications
    @Environment(DeepLinkRouter.self) private var deepLinks
    @Environment(LiveActivityCoordinator.self) private var liveActivities
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPaired = DeviceIdentity.isPaired
    @State private var selectedFeed = FeedSelection.current
    @State private var showsFeedPicker = false
    @State private var showsPairing = false
    @State private var diagnosticsPanel: DiagnosticsPanel?

    var body: some View {
        @Bindable var deepLinks = deepLinks

        NavigationStack {
            Group {
                if let selectedFeed {
                    FeedHomeView(feed: selectedFeed, chooseFeed: { showsFeedPicker = true })
                } else {
                    ContentUnavailableView {
                        Label("Choose a feed", systemImage: "list.bullet")
                    } description: {
                        Text("Browse all feeds without pairing.")
                    } actions: {
                        Button("Choose Feed") { showsFeedPicker = true }
                        if !isPaired { Button("Pair this device") { showsPairing = true } }
                    }
                }
            }
            .navigationTitle("Clark View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isPaired {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Pair") { showsPairing = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    DiagnosticsMenu(selection: $diagnosticsPanel)
                }
            }
            .diagnosticsPanel($diagnosticsPanel)
            .sheet(isPresented: $showsFeedPicker) {
                FeedPickerView(selected: selectedFeed) { feed in
                    FeedSelection.select(feed)
                    selectedFeed = feed
                }
            }
            .sheet(isPresented: $showsPairing) {
                PairingView(onPaired: {
                    isPaired = true
                    showsPairing = false
                    if selectedFeed == nil {
                        Task {
                            if let feed = try? await FeedDirectoryClient.existingFeed(for: DeviceIdentity.deviceID),
                               selectedFeed == nil {
                                FeedSelection.select(feed)
                                selectedFeed = feed
                            }
                        }
                    }
                })
            }
            .navigationDestination(item: $deepLinks.destination) { destination in
                DeepLinkDetailView(destination: destination)
            }
            .onOpenURL { deepLinks.open($0) }
            .task {
                if selectedFeed == nil {
                    if let feed = try? await FeedDirectoryClient.existingFeed(for: DeviceIdentity.deviceID),
                       selectedFeed == nil {
                        FeedSelection.select(feed)
                        selectedFeed = feed
                    } else if selectedFeed == nil {
                        showsFeedPicker = true
                    }
                }
                await refresh()
            }
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
    }
}

#Preview {
    ContentView()
        .environment(NotificationSettings())
        .environment(DeepLinkRouter())
        .environment(LiveActivityCoordinator())
}
