import SwiftUI

/// Discovers public feeds whenever opened and keeps the current choice on errors.
struct FeedPickerView: View {
    let selected: Feed?
    let onSelect: (Feed) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var feeds: [Feed] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(feeds) { feed in
                        Button {
                            onSelect(feed)
                            dismiss()
                        } label: {
                            HStack {
                                Text(feed.name)
                                Spacer()
                                if feed.id == selected?.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    if isLoading { ProgressView("Loading feeds") }
                    if feeds.isEmpty && !isLoading && errorMessage == nil { Text("No feeds available") }
                } footer: {
                    Text("This feed is used by the app and all Clark View widgets. " +
                         "Selecting it does not subscribe this device to its notifications.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                        Button("Try Again") { Task { await load() } }
                    }
                }
            }
            .navigationTitle("Choose Feed")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
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
