import Foundation

/// Reads the feeds joined by this installation for device-scoped widget choices.
enum DeviceFeedClient {
    private struct Index: Decodable {
        let subscriptions: [JoinedFeed]
    }

    private struct JoinedFeed: Decodable {
        let feedId: String
        let feedName: String

        var feed: Feed { Feed(id: feedId, name: feedName) }
    }

    static func joined() async throws -> [Feed] {
        guard let status = await DeviceStatusClient.fetch(device: DeviceIdentity.deviceID) else {
            throw FeedClientError.invalidResponse
        }
        guard status.registered, let deviceID = status.id else { return [] }

        let url = ServerURL.baseURL.appendingPathComponent("devices/\(deviceID)/subscriptions")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FeedClientError.invalidResponse
        }
        return try JSONDecoder().decode(Index.self, from: data).subscriptions.map(\.feed)
    }
}
