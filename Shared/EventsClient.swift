import Foundation

/// The server's numeric device row for `/devices/:id` routes, cached in the App Group so a
/// widget can read events before the app is next opened. A browser merge moves an
/// installation to another row, so a `device_not_found` response invalidates the cache.
enum DeviceRow {
    private static let key = "deviceRowID"
    private static var defaults: UserDefaults { UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard }

    static var cached: Int? { defaults.object(forKey: key) as? Int }
    static func store(_ id: Int) { defaults.set(id, forKey: key) }
    static func invalidate() { defaults.removeObject(forKey: key) }

    /// `POST /devices` is idempotent and returns this installation's current row.
    static func resolve() async -> Int? {
        if let cached { return cached }
        guard let id = await DeviceStatusClient.register(device: DeviceIdentity.deviceID) else { return nil }
        store(id)
        return id
    }
}

enum EventsClientError: Error, Equatable {
    /// The device row could not be resolved. Not an empty collection.
    case identityUnavailable
    /// A retained legacy feed no longer exists.
    case feedUnavailable
    case invalidResponse
}

/// Reads composed events for this device's lists, or a public preview before joining.
enum EventsClient {
    static func payload(for selection: WidgetSelection, context: FeedRequestContext) async throws -> WidgetPayload {
        guard let query = selection.eventsQuery else { throw EventsClientError.invalidResponse }
        guard let row = await DeviceRow.resolve() else { throw EventsClientError.identityUnavailable }
        do {
            return try await fetch(ServerURL.deviceEventsURL(deviceRow: row, selector: query), context: context)
        } catch Rejection.deviceNotFound {
            // Re-resolve once: the cached row may have been merged away.
            DeviceRow.invalidate()
            guard let fresh = await DeviceRow.resolve(), fresh != row else {
                throw EventsClientError.identityUnavailable
            }
            do {
                return try await fetch(ServerURL.deviceEventsURL(deviceRow: fresh, selector: query), context: context)
            } catch Rejection.deviceNotFound {
                throw EventsClientError.identityUnavailable
            }
        }
    }

    static func preview(listID: String) async throws -> WidgetPayload {
        do {
            return try await fetch(ServerURL.publicEventsURL(viewIDs: [listID]), context: .appPreview)
        } catch Rejection.deviceNotFound {
            throw EventsClientError.invalidResponse
        }
    }

    private enum Rejection: Error { case deviceNotFound }

    private static func fetch(_ url: URL, context: FeedRequestContext) async throws -> WidgetPayload {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        context.apply(to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw EventsClientError.invalidResponse }
        if status == 404 {
            struct Failure: Decodable { let error: String }
            switch (try? JSONDecoder().decode(Failure.self, from: data))?.error {
            case "device_not_found": throw Rejection.deviceNotFound
            case "feed_not_found", "view_not_found": throw EventsClientError.feedUnavailable
            default: throw EventsClientError.invalidResponse
            }
        }
        guard status == 200 else { throw EventsClientError.invalidResponse }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(WidgetPayload.self, from: data)
    }
}
