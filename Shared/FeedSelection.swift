import Foundation
import WidgetKit

/// One installation-wide native feed choice, independent of pairing and push identity.
struct Feed: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

enum FeedSelection {
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard
    private static let idKey = "selectedFeedID"
    private static let nameKey = "selectedFeedName"
    private static let revisionKey = "selectedFeedRevision"
    private static let unavailableKey = "unavailableFeedID"

    static var current: Feed? {
        guard let id = defaults.string(forKey: idKey),
              let name = defaults.string(forKey: nameKey) else { return nil }
        return Feed(id: id, name: name)
    }

    static var revision: String { defaults.string(forKey: revisionKey) ?? "" }
    static var isUnavailable: Bool {
        current?.id != nil && defaults.string(forKey: unavailableKey) == current?.id
    }

    static func setUnavailable(_ unavailable: Bool, for feed: Feed, revision: String) {
        guard current?.id == feed.id, self.revision == revision else { return }
        if unavailable {
            defaults.set(feed.id, forKey: unavailableKey)
        } else if defaults.string(forKey: unavailableKey) == feed.id {
            defaults.removeObject(forKey: unavailableKey)
        }
    }

    static func select(_ feed: Feed) {
        guard current?.id != feed.id else {
            defaults.set(feed.name, forKey: nameKey)
            return
        }
        defaults.set(feed.id, forKey: idKey)
        defaults.set(feed.name, forKey: nameKey)
        defaults.set(UUID().uuidString, forKey: revisionKey)
        defaults.removeObject(forKey: unavailableKey)
        defaults.removeObject(forKey: "latestWidgetPayload")
        defaults.removeObject(forKey: "latestWidgetPayloadFeedID")
        defaults.removeObject(forKey: "latestWidgetPayloadRevision")
        WidgetFocusStore.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.main)
    }
}

enum FeedDirectoryClient {
    static func list() async throws -> [Feed] {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(
            url: ServerURL.feedsURL, cachePolicy: .reloadIgnoringLocalCacheData
        ))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FeedClientError.invalidResponse }
        return try JSONDecoder().decode(Directory.self, from: data).feeds
    }

    static func existingFeed(for installationID: String) async throws -> Feed? {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(
            url: ServerURL.installationFeedURL(installationID), cachePolicy: .reloadIgnoringLocalCacheData
        ))
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw FeedClientError.invalidResponse }
        if status == 404 { return nil }
        guard status == 200 else { throw FeedClientError.invalidResponse }
        return try JSONDecoder().decode(Feed.self, from: data)
    }

    static func payload(for feed: Feed) async throws -> WidgetPayload {
        try await payloadWithData(for: feed).0
    }

    static func payloadWithData(for feed: Feed) async throws -> (WidgetPayload, Data) {
        let revision = FeedSelection.revision
        let url = ServerURL.feedURL(feed.id, timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw FeedClientError.invalidResponse }
        if status == 404 {
            FeedSelection.setUnavailable(true, for: feed, revision: revision)
            throw FeedClientError.unavailable
        }
        guard status == 200 else { throw FeedClientError.invalidResponse }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let payload = try decoder.decode(WidgetPayload.self, from: data)
        FeedSelection.setUnavailable(false, for: feed, revision: revision)
        return (payload, data)
    }

    private struct Directory: Decodable { let feeds: [Feed] }
}

enum FeedClientError: Error, Equatable {
    case invalidResponse
    case unavailable
}
