import SwiftUI

/// Public directory and pre-join preview for this installation.
struct ListDirectoryView: View {
    @Environment(ListStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var lists: [ListSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading views")
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Views unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else {
                    List {
                        if unjoined.isEmpty {
                            ContentUnavailableView("All views joined", systemImage: "checkmark.circle")
                        }
                        ForEach(unjoined) { list in
                            NavigationLink {
                                JoinListPreviewView(list: list, onJoined: { dismiss() })
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                    Text(list.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Views")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private var unjoined: [ListSummary] {
        lists.filter { store.list(id: $0.id) == nil }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lists = try await ListClient.directory()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t load views. Try again."
        }
    }
}

struct JoinListPreviewView: View {
    let list: ListSummary
    let onJoined: () -> Void
    @Environment(ListStore.self) private var store
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        FeedPreviewView(list: list.list) {
            EmptyView()
        } trailing: {
            VStack(alignment: .leading, spacing: 16) {
                Button("Join view") { Task { await join() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || store.deviceID == nil)
                if store.deviceID == nil {
                    Text("This device’s views haven’t loaded. Try again to join.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try Again") { Task { await store.load() } }
                        .buttonStyle(.borderless)
                }
                Text("Joining adds this view to widgets showing All my views. " +
                     "Reminders start off; turn them on from the view.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if list.freshness.isLapsed {
                    Text("This view hasn’t been updated on its usual schedule, so its events may be out of date.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func join() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.join(list)
            onJoined()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
