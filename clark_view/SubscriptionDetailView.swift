import SwiftUI

/// A legacy feed's preview, reminder state, and sources. Read-only: legacy membership is frozen.
struct SubscriptionDetailView: View {
    let id: Int
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let subscription = store.subscription(id: id) {
            FeedPreviewView(feed: subscription.feed) {
                Label(subscription.enabled ? "Reminders on" : "Reminders off",
                      systemImage: subscription.enabled ? "bell.fill" : "bell.slash")
                    .foregroundStyle(subscription.enabled ? Color.accentColor : Color.secondary)
            } trailing: {
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink {
                        FeedSourcesView(feed: subscription.feed)
                    } label: {
                        Label("Sources", systemImage: "tray.full")
                    }
                    DisclosureGroup("About reminders") {
                        Text("This feed sets reminders \(ReminderLead.label(subscription.reminderLeadSeconds)) " +
                             "and can change the timing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(subscription.feedName)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Feed no longer joined", systemImage: "bell.slash")
                .task { dismiss() }
        }
    }
}
