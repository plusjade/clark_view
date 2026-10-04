import SwiftUI

/// Home screen: published views joined by this installation, each with its own reminder state.
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
                LegacyFeedsView()
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
            if store.lists.contains(where: \.remindersEnabled), let delivery = store.delivery {
                DeliveryStatusSection(delivery: delivery, openNotifications: openNotifications)
            }
            if !legacy.subscriptions.isEmpty {
                Section {
                    NavigationLink(value: LegacyFeedsRoute()) {
                        Label("Feeds from earlier versions", systemImage: "clock.arrow.circlepath")
                    }
                } footer: {
                    Text("Feeds joined in earlier versions. They can no longer be changed, and their reminders have stopped.")
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                if list.freshness.isLapsed {
                    Text("Not updated recently")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: list.remindersEnabled ? "bell.fill" : "bell.slash")
                .foregroundStyle(list.remindersEnabled ? Color.accentColor : Color.secondary)
                .accessibilityLabel(list.remindersEnabled ? "Reminders on" : "Reminders off")
        }
    }
}

/// Whether this device can currently receive reminder alerts.
struct DeliveryStatusSection: View {
    let delivery: String
    let openNotifications: () -> Void

    var body: some View {
        switch delivery {
        case "ready":
            Section("This device") {
                status("Ready for reminders", symbol: "checkmark.circle.fill", color: .green)
            }
        case "permission_denied":
            Section("This device") {
                status("Notifications off", symbol: "bell.slash.fill", color: .orange)
                Button("Review notification settings", action: openNotifications)
            }
        case "no_token":
            Section("This device") {
                status("Notifications not ready", symbol: "exclamationmark.circle.fill", color: .orange)
                Button("Review notification settings", action: openNotifications)
            }
        default:
            EmptyView()
        }
    }

    private func status(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(title)
        }
    }
}

/// Read-only compatibility screen for feeds joined before lists; legacy membership is frozen.
struct LegacyFeedsView: View {
    var body: some View {
        SubscriptionListView()
            .navigationTitle("Earlier feeds")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("These feeds were joined in an earlier version and can no longer be changed. " +
                     "Their reminders have stopped. " +
                     "Views are managed in My views.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
    }
}
