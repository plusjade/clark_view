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
            } footer: {
                if store.subscriptions.contains(where: \.enabled) { deliveryFooter }
            }
            if case .failed(let message) = store.phase {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .refreshable { await store.load() }
    }

    @ViewBuilder private var deliveryFooter: some View {
        switch store.delivery {
        case "ready":
            Label("This device is ready to receive reminders when they are on.",
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.mint)
        case "permission_denied":
            needsSetup("Push notifications are off for this app, so reminders can’t arrive.")
        case "no_token":
            needsSetup("This device hasn’t registered for push notifications yet, so reminders can’t arrive.")
        default:
            EmptyView()
        }
    }

    private func needsSetup(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note)
            Button("Open Notifications", action: openNotifications)
                .font(.footnote.weight(.semibold))
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
            Text(subscription.enabled
                 ? "Reminders on · \(ReminderLead.label(subscription.reminderLeadSeconds))"
                 : "Reminders off")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
