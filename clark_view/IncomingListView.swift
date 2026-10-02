import SwiftUI

/// A shared list link resolves its current server identity before showing a
/// preview or this device's existing membership.
struct IncomingListView: View {
    let id: String
    @Environment(ListStore.self) private var store
    @State private var list: ListSummary?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let list {
                if store.list(id: id) != nil {
                    ListDetailView(id: id)
                } else {
                    JoinListPreviewView(list: list, onJoined: {})
                }
            } else if isLoading {
                ProgressView("Opening list")
            } else {
                ContentUnavailableView {
                    Label("List unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage ?? "Couldn’t open this list.")
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // The link contains only an ID. Both identity and edit capability come
            // from the parent; a join still requires the person's explicit action.
            async let detail = ListClient.detail(id: id)
            if store.deviceID == nil { await store.load() }
            list = try await detail
            errorMessage = nil
        } catch {
            list = nil
            errorMessage = error.localizedDescription
        }
    }
}
