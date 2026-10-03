import SwiftUI
import UIKit

/// A joined view's events, its maintenance status, and agent editing handoff.
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
                    if list.freshness.isLapsed {
                        Label("Not updated recently; events may be out of date",
                              systemImage: "clock.badge.exclamationmark")
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
                    if let stateUrl = metadata?.stateUrl {
                        Button("Copy editing instructions", systemImage: "doc.on.doc") {
                            let introduction = "Help me edit the view \"\(list.name)\" in Clark View. "
                            let instructions = "Read \(stateUrl.absoluteString) for its current state " +
                                "and editing instructions, then apply the changes I request. " +
                                "Preserve unrelated events and shared preferences. " +
                                "Edits affect everyone who joins this view."
                            UIPasteboard.general.string = introduction + instructions
                            copiedInstructions = true
                        }
                        .buttonStyle(.borderless)
                        Text("An agent can update this view for everyone who joins it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if copiedInstructions {
                            Text("Instructions copied. Paste them into a conversation with an agent.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Leave view", role: .destructive) { confirmsLeave = true }
                        .buttonStyle(.borderless)
                        .disabled(isSaving)
                }
            }
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: id) { metadata = try? await ListClient.detail(id: id) }
            .confirmationDialog("Leave view?", isPresented: $confirmsLeave, titleVisibility: .visible) {
                Button("Leave view", role: .destructive) { Task { await leave(list) } }
            } message: {
                Text("Its events leave your widgets on this device.")
            }
        } else {
            ContentUnavailableView("View no longer joined", systemImage: "list.bullet.rectangle")
                .task { dismiss() }
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
