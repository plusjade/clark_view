import SwiftUI

/// Home screen: published views joined by this installation.
struct MyListsView: View {
    let openNotifications: () -> Void
    @Environment(ListStore.self) private var store
    @Environment(SubscriptionStore.self) private var legacy
    @State private var showsDirectory = false

    var body: some View {
        content
            .toolbar {
                if store.deviceID != nil {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()
                        Button("Browse views", systemImage: "plus") { showsDirectory = true }
                    }
                }
            }
            .sheet(isPresented: $showsDirectory) { ListDirectoryView() }
            .navigationDestination(for: ListRoute.self) { ListDetailView(id: $0.id) }
            .navigationDestination(for: LegacyFeedsRoute.self) { _ in
                LegacyFeedsView(openNotifications: openNotifications)
            }
            .accessibilityIdentifier("myLists")
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .loading where store.lists.isEmpty:
            ProgressView("Loading your views")
        case .failed(let message) where store.lists.isEmpty:
            ContentUnavailableView {
                Label("Your views unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await store.load() } }
            }
        default:
            list
        }
    }

    private var list: some View {
        List {
            if store.lists.isEmpty {
                ContentUnavailableView {
                    Label("No views joined", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Join a view to see its events in widgets showing All my views.")
                } actions: {
                    Button("Browse views") { showsDirectory = true }
                }
            }
            Section {
                ForEach(store.lists) { list in
                    NavigationLink(value: ListRoute(id: list.id)) {
                        JoinedListRow(list: list)
                    }
                }
            }
            if case .failed(let message) = store.phase {
                Section { Text(message).foregroundStyle(.secondary) }
            }
            if !legacy.subscriptions.isEmpty {
                Section {
                    NavigationLink(value: LegacyFeedsRoute()) {
                        Label("Feeds from earlier versions", systemImage: "clock.arrow.circlepath")
                    }
                } footer: {
                    Text("Feeds joined in earlier versions. They can no longer be changed.")
                }
            }
        }
        .refreshable {
            await store.load()
            await legacy.load()
        }
    }
}

struct ListRoute: Hashable {
    let id: String
}

struct LegacyFeedsRoute: Hashable {}

private struct JoinedListRow: View {
    let list: JoinedList

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name)
            if list.freshness.isLapsed {
                Text("Not updated recently")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Read-only compatibility screen for feeds joined before lists; legacy membership is frozen.
struct LegacyFeedsView: View {
    let openNotifications: () -> Void

    var body: some View {
        SubscriptionListView(openNotifications: openNotifications)
            .navigationTitle("Earlier feeds")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("These feeds were joined in an earlier version and can no longer be changed. " +
                     "Views are managed in My views.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
    }
}
