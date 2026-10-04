import SwiftUI

/// A legacy feed's preview and sources. Read-only: legacy membership is frozen and its reminders are paused.
struct SubscriptionDetailView: View {
    let id: Int
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let subscription = store.subscription(id: id) {
            FeedPreviewView(feed: subscription.feed) {
                Label("Reminders stopped", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
            } trailing: {
                VStack(alignment: .leading, spacing: 16) {
                    NavigationLink {
                        FeedSourcesView(feed: subscription.feed)
                    } label: {
                        Label("Sources", systemImage: "tray.full")
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
