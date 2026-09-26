import SwiftUI

/// Show screen: the subscription's reminder policy above a preview of its nested feed.
struct SubscriptionDetailView: View {
    let id: Int
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showsEdit = false

    var body: some View {
        if let subscription = store.subscription(id: id) {
            FeedPreviewView(feed: subscription.feed) {
                SubscriptionSummary(subscription: subscription)
            }
            .navigationTitle(subscription.feedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button("Edit") { showsEdit = true } }
            }
            .sheet(isPresented: $showsEdit) { SubscriptionFormView(mode: .edit(subscription)) }
        } else {
            ContentUnavailableView("Subscription removed", systemImage: "bell.slash")
                .task { dismiss() }
        }
    }
}

private struct SubscriptionSummary: View {
    let subscription: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(subscription.enabled ? "Reminders on" : "Reminders paused",
                  systemImage: subscription.enabled ? "bell.fill" : "bell.slash")
                .font(.headline)
            Text(ReminderLead.label(subscription.reminderLeadSeconds))
                .foregroundStyle(.secondary)
            Divider().padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
