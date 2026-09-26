import SwiftUI

/// New and edit screens for a subscription. A new subscription defaults to a one-hour reminder lead.
struct SubscriptionFormView: View {
    enum Mode {
        case new
        case edit(Subscription)
    }

    let mode: Mode
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var feeds: [Feed] = []
    @State private var isLoadingFeeds = false
    @State private var feedID: String?
    @State private var leadSeconds: Int
    @State private var enabled: Bool
    @State private var isSaving = false
    @State private var confirmsRemoval = false
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .new:
            _leadSeconds = State(initialValue: ReminderLead.defaultSeconds)
            _enabled = State(initialValue: true)
        case .edit(let subscription):
            _leadSeconds = State(initialValue: subscription.reminderLeadSeconds)
            _enabled = State(initialValue: subscription.enabled)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                feedSection
                Section {
                    Picker("Reminder", selection: $leadSeconds) {
                        ForEach(leadOptions, id: \.self) { Text(ReminderLead.label($0)).tag($0) }
                    }
                    if case .edit = mode { Toggle("Enabled", isOn: $enabled) }
                } footer: {
                    Text("Reminders arrive this long before each event in the feed starts.")
                }
                if case .edit = mode {
                    Section {
                        Button("Remove Subscription", role: .destructive) { confirmsRemoval = true }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(isNew ? "New Subscription" : "Edit Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { Task { await save() } }
                        .disabled(isSaving || (isNew && feedID == nil))
                }
            }
            .confirmationDialog("Remove this subscription?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
                Button("Remove Subscription", role: .destructive) { Task { await remove() } }
            } message: {
                Text("This device will stop getting reminders for this feed.")
            }
            .interactiveDismissDisabled(isSaving)
            .task { if isNew { await loadFeeds() } }
        }
    }

    @ViewBuilder private var feedSection: some View {
        switch mode {
        case .new:
            Section("Feed") {
                if isLoadingFeeds {
                    ProgressView("Loading feeds")
                } else if availableFeeds.isEmpty {
                    Text("Every feed already has a subscription.").foregroundStyle(.secondary)
                } else {
                    Picker("Feed", selection: $feedID) {
                        Text("Choose a feed").tag(String?.none)
                        ForEach(availableFeeds) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
            }
        case .edit(let subscription):
            Section("Feed") { Text(subscription.feedName) }
        }
    }

    private var isNew: Bool {
        if case .new = mode { return true }
        return false
    }

    private var availableFeeds: [Feed] {
        feeds.filter { feed in !store.subscriptions.contains { $0.feedId == feed.id } }
    }

    /// Presets plus a stored lead set elsewhere (e.g. the browser), so editing never silently changes it.
    private var leadOptions: [Int] {
        Set(ReminderLead.presets + [leadSeconds]).sorted()
    }

    private func loadFeeds() async {
        isLoadingFeeds = true
        defer { isLoadingFeeds = false }
        do {
            feeds = try await FeedDirectoryClient.list()
        } catch {
            errorMessage = "Couldn’t load feeds. Try again."
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .new:
                guard let feedID else { return }
                try await store.create(feedID: feedID, leadSeconds: leadSeconds)
            case .edit(let subscription):
                try await store.update(subscription, leadSeconds: leadSeconds, enabled: enabled)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove() async {
        guard case .edit(let subscription) = mode else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.delete(subscription)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
