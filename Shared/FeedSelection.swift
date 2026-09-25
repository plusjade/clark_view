import Foundation

/// The app's persistent feed choice, independent of widgets, pairing, and push identity.
struct Feed: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

enum FeedSelection {
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard
    private static let idKey = "selectedFeedID"
    private static let nameKey = "selectedFeedName"

    static var current: Feed? {
        guard let id = defaults.string(forKey: idKey),
              let name = defaults.string(forKey: nameKey) else { return nil }
        return Feed(id: id, name: name)
    }

    static func select(_ feed: Feed) {
        guard current?.id != feed.id else {
            defaults.set(feed.name, forKey: nameKey)
            return
        }
        defaults.set(feed.id, forKey: idKey)
        defaults.set(feed.name, forKey: nameKey)
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
        let url = ServerURL.feedURL(feed.id, timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier)
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw FeedClientError.invalidResponse }
        if status == 404 { throw FeedClientError.unavailable }
        guard status == 200 else { throw FeedClientError.invalidResponse }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let payload = try decoder.decode(WidgetPayload.self, from: data)
        return (payload, data)
    }

    private struct Directory: Decodable { let feeds: [Feed] }
}

enum FeedClientError: Error, Equatable {
    case invalidResponse
    case unavailable
}
