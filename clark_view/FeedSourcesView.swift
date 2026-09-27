import SwiftUI

/// A source attached to a feed; assignment changes remain browser-managed.
private struct FeedSource: Decodable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let enabled: Bool
}

private enum FeedSourceClient {
    private struct Details: Decodable { let sources: [FeedSource] }

    static func sources(for feed: Feed) async throws -> [FeedSource] {
        let url = ServerURL.feedsURL.appendingPathComponent(feed.id).appendingPathComponent("details")
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw FeedClientError.invalidResponse
        }
        if status == 404 { throw FeedClientError.unavailable }
        guard status == 200 else { throw FeedClientError.invalidResponse }
        return try JSONDecoder().decode(Details.self, from: data).sources
    }
}

/// Read-only source membership for a feed; configuration stays in the browser.
struct FeedSourcesView: View {
    let feed: Feed
    @State private var sources: [FeedSource]?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let sources {
                List {
                    if sources.isEmpty {
                        ContentUnavailableView("No sources", systemImage: "tray")
                    } else {
                        Section {
                            ForEach(sources) { source in
                                sourceRow(source)
                            }
                        } footer: {
                            Text("Sources are managed by the feed owner.")
                        }
                    }
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .refreshable { await load() }
            } else if isLoading {
                ProgressView("Loading sources")
            } else {
                ContentUnavailableView {
                    Label("Sources unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    if let errorMessage { Text(errorMessage) }
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            }
        }
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func sourceRow(_ source: FeedSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                Text(source.kind)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !source.enabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sources = try await FeedSourceClient.sources(for: feed)
            errorMessage = nil
        } catch {
            errorMessage = error is FeedClientError && (error as? FeedClientError) == .unavailable
                ? "This feed is no longer available."
                : "Couldn’t load sources. Pull down to retry."
        }
    }
}
