import SwiftUI

/// Feeds joined by this installation before lists.
struct SubscriptionListView: View {
    @Environment(SubscriptionStore.self) private var store

    var body: some View {
        content
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
                ContentUnavailableView("No feeds joined", systemImage: "rectangle.stack")
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
        }
        .refreshable { await store.load() }
    }
}

struct SubscriptionRoute: Hashable {
    let id: Int
}

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        Text(subscription.feedName)
    }
}
