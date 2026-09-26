import SwiftUI

/// Public directory and pre-join preview for this installation.
struct SubscriptionFormView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var feeds: [Feed] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading feeds")
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Feeds unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else {
                    List {
                        if availableFeeds.isEmpty {
                            ContentUnavailableView("All feeds joined", systemImage: "checkmark.circle")
                        }
                        ForEach(availableFeeds) { feed in
                            NavigationLink(feed.name) { JoinFeedPreviewView(feed: feed, onJoined: { dismiss() }) }
                        }
                    }
                }
            }
            .navigationTitle("Join feed")
            .task { await load() }
        }
    }

    private var availableFeeds: [Feed] {
        feeds.filter { feed in !store.subscriptions.contains { $0.feedId == feed.id } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            feeds = try await FeedDirectoryClient.list()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load feeds. Try again."
        }
    }
}

private struct JoinFeedPreviewView: View {
    let feed: Feed
    let onJoined: () -> Void
    @Environment(SubscriptionStore.self) private var store
    @State private var reminders = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        FeedPreviewView(feed: feed) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shared reminder timing: " +
                     ReminderLead.label(feed.reminderLeadSeconds ?? ReminderLead.defaultSeconds))
                Text("The feed maintains this timing, and it can change.")
                    .foregroundStyle(.secondary)
                Toggle("Reminders", isOn: $reminders)
                Button("Join feed") { Task { await join() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                Text("Joining keeps this feed in Your feeds. Widget selection stays independent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(feed.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func join() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.create(feedID: feed.id, enabled: reminders)
            onJoined()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
