import SwiftUI

/// A joined feed's preview and this device's reminder preference.
struct SubscriptionDetailView: View {
    let id: Int
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsLeave = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        if let subscription = store.subscription(id: id) {
            FeedPreviewView(feed: subscription.feed) {
                VStack(alignment: .leading, spacing: 12) {
                    FeedReminderToggle(isOn: Binding(
                        get: { subscription.enabled },
                        set: { value in Task { await setReminders(value, for: subscription) } }
                    ), isDisabled: isSaving)
                    if subscription.enabled, store.delivery == "permission_denied" {
                        Label("Notifications off on this device", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    } else if subscription.enabled, store.delivery == "no_token" {
                        Label("Notifications not ready on this device", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
            } trailing: {
                VStack(alignment: .leading, spacing: 16) {
                    DisclosureGroup("About reminders") {
                        Text("This feed sets reminders \(ReminderLead.label(subscription.reminderLeadSeconds)) " +
                             "before start and can change the timing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button("Leave feed", role: .destructive) { confirmsLeave = true }
                        .buttonStyle(.borderless)
                        .disabled(isSaving)
                }
            }
            .navigationTitle(subscription.feedName)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Leave feed?", isPresented: $confirmsLeave, titleVisibility: .visible) {
                Button("Leave feed", role: .destructive) { Task { await leave(subscription) } }
            } message: {
                Text("This device will stop receiving reminders for this feed. " +
                     "An independently selected widget stays in place.")
            }
        } else {
            ContentUnavailableView("Feed no longer joined", systemImage: "bell.slash")
                .task { dismiss() }
        }
    }

    private func setReminders(_ enabled: Bool, for subscription: Subscription) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.update(subscription, enabled: enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leave(_ subscription: Subscription) async {
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
