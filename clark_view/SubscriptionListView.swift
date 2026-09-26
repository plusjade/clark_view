import SwiftUI

/// Home screen: this device's feed subscriptions. Each subscription opens its reminder policy and nested feed.
struct SubscriptionListView: View {
    let pair: () -> Void
    @Environment(SubscriptionStore.self) private var store
    @State private var showsNew = false
    @State private var actionError: String?

    var body: some View {
        content
            .toolbar {
                if store.deviceID != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Subscription", systemImage: "plus") { showsNew = true }
                    }
                }
            }
            .sheet(isPresented: $showsNew) { SubscriptionFormView(mode: .new) }
            .navigationDestination(for: SubscriptionRoute.self) { SubscriptionDetailView(id: $0.id) }
            .accessibilityIdentifier("subscriptions")
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .loading where store.subscriptions.isEmpty:
            ProgressView("Loading subscriptions")
        case .unregistered:
            ContentUnavailableView {
                Label("Pair this device", systemImage: "bell.badge")
            } description: {
                Text("Subscriptions belong to a paired device.")
            } actions: {
                Button("Pair this device", action: pair)
            }
        case .failed(let message) where store.subscriptions.isEmpty:
            ContentUnavailableView {
                Label("Subscriptions unavailable", systemImage: "wifi.exclamationmark")
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
                    Label("No subscriptions", systemImage: "bell")
                } description: {
                    Text("Subscribe to a feed to get reminders before its events.")
                } actions: {
                    Button("New Subscription") { showsNew = true }
                }
            }
            Section {
                ForEach(store.subscriptions) { subscription in
                    NavigationLink(value: SubscriptionRoute(id: subscription.id)) {
                        SubscriptionRow(subscription: subscription)
                    }
                }
                .onDelete { offsets in
                    let removed = offsets.map { store.subscriptions[$0] }
                    Task {
                        do {
                            for subscription in removed { try await store.delete(subscription) }
                            actionError = nil
                        } catch {
                            actionError = error.localizedDescription
                        }
                    }
                }
            } footer: {
                if let note = deliveryNote { Text(note) }
            }
            if let actionError {
                Section { Text(actionError).foregroundStyle(.red) }
            }
            if case .failed(let message) = store.phase {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .refreshable { await store.load() }
    }

    private var deliveryNote: String? {
        switch store.delivery {
        case "permission_denied": "Notifications are off for this app, so reminders can’t arrive."
        case "no_token": "This device hasn’t registered for reminders yet. Open Notifications from the menu."
        default: nil
        }
    }
}

struct SubscriptionRoute: Hashable {
    let id: Int
}

private struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subscription.feedName)
            Text(subscription.enabled ? ReminderLead.label(subscription.reminderLeadSeconds) : "Paused")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
