import SwiftUI

/// Home screen: feeds joined by this installation, whether reminders are on or off.
struct SubscriptionListView: View {
    let openNotifications: () -> Void
    @Environment(SubscriptionStore.self) private var store
    @State private var showsNew = false

    var body: some View {
        content
            .toolbar {
                if store.deviceID != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Join feed", systemImage: "plus") { showsNew = true }
                    }
                }
            }
            .sheet(isPresented: $showsNew) { SubscriptionFormView() }
            .navigationDestination(for: SubscriptionRoute.self) { SubscriptionDetailView(id: $0.id) }
            .accessibilityIdentifier("yourFeeds")
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .loading where store.subscriptions.isEmpty:
            ProgressView("Loading your feeds")
        case .failed(let message) where store.subscriptions.isEmpty:
            ContentUnavailableView {
                Label("Your feeds unavailable", systemImage: "wifi.exclamationmark")
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
            if store.subscriptions.isEmpty {
                ContentUnavailableView {
                    Label("No feeds joined", systemImage: "rectangle.stack")
                } description: {
                    Text("Join a public feed to keep it here. You can turn reminders on when you want them.")
                } actions: {
                    Button("Join feed") { showsNew = true }
                }
            }
            Section {
                ForEach(store.subscriptions) { subscription in
                    NavigationLink(value: SubscriptionRoute(id: subscription.id)) {
                        SubscriptionRow(subscription: subscription)
                    }
                }
            }
            if case .failed(let message) = store.phase {
                Section { Text(message).foregroundStyle(.secondary) }
            }
            if store.subscriptions.contains(where: \.enabled),
               let delivery = store.delivery,
               ["ready", "permission_denied", "no_token"].contains(delivery) {
                deliverySection
            }
        }
        .refreshable { await store.load() }
    }

    private var deliverySection: some View {
        Section("This device") {
            switch store.delivery {
            case "ready":
                deliveryStatus("Ready for reminders", symbol: "checkmark.circle.fill", color: .green)
            case "permission_denied":
                deliveryStatus("Notifications off", symbol: "bell.slash.fill", color: .orange)
                Button("Review notification settings", action: openNotifications)
            case "no_token":
                deliveryStatus("Notifications not ready", symbol: "exclamationmark.circle.fill", color: .orange)
                Button("Review notification settings", action: openNotifications)
            default:
                EmptyView()
            }
        }
    }

    private func deliveryStatus(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(title)
        }
    }
}

struct SubscriptionRoute: Hashable {
    let id: Int
}

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        HStack {
            Text(subscription.feedName)
            Spacer()
            Image(systemName: subscription.enabled ? "bell.fill" : "bell.slash")
                .foregroundStyle(subscription.enabled ? Color.accentColor : Color.secondary)
                .accessibilityLabel(subscription.enabled ? "Reminders on" : "Reminders off")
        }
    }
}
