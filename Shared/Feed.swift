import Foundation

/// A public feed from the `/feeds` directory; widgets select one and subscriptions nest one.
struct Feed: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

enum FeedDirectoryClient {
    static func list() async throws -> [Feed] {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(
            url: ServerURL.feedsURL, cachePolicy: .reloadIgnoringLocalCacheData
        ))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FeedClientError.invalidResponse }
        return try JSONDecoder().decode(Directory.self, from: data).feeds
    }

    static func payload(for feed: Feed, context: FeedRequestContext) async throws -> WidgetPayload {
        try await payloadWithData(for: feed, context: context).0
    }

    static func payloadWithData(for feed: Feed, context: FeedRequestContext) async throws -> (WidgetPayload, Data) {
        let url = ServerURL.feedURL(feed.id, timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        context.apply(to: &request)
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

/// Optional receipt headers; the server records them only for a registered installation.
struct FeedRequestContext {
    let caller: String
    let family: String?
    let purpose: String

    static let appPreview = FeedRequestContext(caller: "app", family: nil, purpose: "preview")

    func apply(to request: inout URLRequest) {
        request.setValue(DeviceIdentity.deviceID, forHTTPHeaderField: "X-Clark-Installation")
        request.setValue(caller, forHTTPHeaderField: "X-Clark-Caller")
        request.setValue(family, forHTTPHeaderField: "X-Clark-Widget-Family")
        request.setValue(purpose, forHTTPHeaderField: "X-Clark-Request-Purpose")
    }
}

enum FeedClientError: Error, Equatable {
    case invalidResponse
    case unavailable
}
