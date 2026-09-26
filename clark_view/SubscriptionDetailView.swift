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
                    Text("Shared reminder timing: \(ReminderLead.label(subscription.reminderLeadSeconds))")
                    Text("The feed maintains this timing, and it can change.")
                        .foregroundStyle(.secondary)
                    Toggle("Reminders", isOn: Binding(
                        get: { subscription.enabled },
                        set: { value in Task { await setReminders(value, for: subscription) } }
                    ))
                    .disabled(isSaving)
                    if subscription.enabled, store.delivery == "permission_denied" {
                        Text("Reminders are on here, but iOS notification permission is off. " +
                             "Enable it in Settings to receive alerts.")
                            .foregroundStyle(.secondary)
                    } else if subscription.enabled, store.delivery == "no_token" {
                        Text("Reminders are on here, but this device has no alert token yet.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Leave feed", role: .destructive) { confirmsLeave = true }
                        .disabled(isSaving)
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
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
