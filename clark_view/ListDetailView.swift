import SwiftUI
import UIKit

/// A joined list's events and this device's reminder preference.
struct ListDetailView: View {
    let id: String
    @Environment(ListStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsLeave = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var metadata: ListSummary?
    @State private var copiedInstructions = false

    var body: some View {
        if let list = store.list(id: id) {
            FeedPreviewView(list: list.list) {
                VStack(alignment: .leading, spacing: 12) {
                    FeedReminderToggle(isOn: Binding(
                        get: { list.remindersEnabled },
                        set: { value in Task { await setReminders(value, for: list) } }
                    ), isDisabled: isSaving)
                    if list.remindersEnabled, store.delivery == "permission_denied" {
                        Label("Notifications off on this device", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    } else if list.remindersEnabled, store.delivery == "no_token" {
                        Label("Notifications not ready on this device", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    if !list.available {
                        Label("This list is temporarily unavailable", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                }
            } trailing: {
                VStack(alignment: .leading, spacing: 16) {
                    if !list.description.isEmpty {
                        Text(list.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    DisclosureGroup("About reminders") {
                        Text("This list sets reminders \(ReminderLead.label(list.reminderLeadSeconds)).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let management = metadata?.management, management.version == 2 {
                        Button("Copy editing instructions", systemImage: "doc.on.doc") {
                            let introduction = "Help me edit the Clark View list \"\(list.name)\". "
                            let instructions = "Read \(management.stateUrl.absoluteString) for its current state " +
                                "and editing instructions, then apply the changes I request. " +
                                "Preserve unrelated events and shared preferences. " +
                                "Edits affect everyone who joins this list."
                            UIPasteboard.general.string = introduction + instructions
                            copiedInstructions = true
                        }
                        .buttonStyle(.borderless)
                        Text("An agent can update this list for everyone who joins it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if copiedInstructions {
                            Text("Instructions copied. Paste them into a conversation with an agent.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Leave list", role: .destructive) { confirmsLeave = true }
                        .buttonStyle(.borderless)
                        .disabled(isSaving)
                }
            }
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: id) { metadata = try? await ListClient.detail(id: id) }
            .confirmationDialog("Leave list?", isPresented: $confirmsLeave, titleVisibility: .visible) {
                Button("Leave list", role: .destructive) { Task { await leave(list) } }
            } message: {
                Text("Its events leave your widgets and its reminders stop on this device.")
            }
        } else {
            ContentUnavailableView("List no longer joined", systemImage: "list.bullet.rectangle")
                .task { dismiss() }
        }
    }

    private func setReminders(_ enabled: Bool, for list: JoinedList) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.setReminders(list, enabled: enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leave(_ list: JoinedList) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.leave(list)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
