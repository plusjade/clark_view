import Foundation

/// A device's join and reminder preference; timing belongs to the feed.
struct Subscription: Decodable, Hashable, Identifiable {
    let id: Int
    let feedId: String
    let feedName: String
    let enabled: Bool
    let reminderLeadSeconds: Int

    var feed: Feed { Feed(id: feedId, name: feedName) }
}

enum ReminderLead {
    static let defaultSeconds = 3600
    static let maxSeconds = 36 * 60 * 60
    static let presets = [0, 300, 900, 1800, 3600, 7200, 21_600, 43_200, 86_400, maxSeconds]

    static func label(_ seconds: Int) -> String {
        guard seconds > 0 else { return "At start" }
        let duration = Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return "\(duration) before start"
    }
}

enum SubscriptionClientError: LocalizedError, Equatable {
    case invalidResponse
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Couldn’t reach the server. Try again."
        case .rejected(let message): message
        }
    }
}

/// Uses the browser's form routes under `/devices/:id/subscriptions`, asking for JSON instead of HTML.
/// `deviceID` is the server's numeric device row, resolved from this installation's status.
enum SubscriptionClient {
    struct Index: Decodable {
        let subscriptions: [Subscription]
        let delivery: String
    }

    static func index(deviceID: Int) async throws -> Index {
        let (data, status) = try await send(request(path(deviceID)))
        guard status == 200 else { throw rejection(data) }
        return try JSONDecoder().decode(Index.self, from: data)
    }

    static func create(deviceID: Int, feedID: String, enabled: Bool) async throws {
        try await post(path(deviceID), form: ["feedId": feedID, "enabled": enabled ? "1" : "0"])
    }

    static func update(deviceID: Int, subscriptionID: Int, enabled: Bool) async throws {
        try await post("\(path(deviceID))/\(subscriptionID)",
                       form: ["enabled": enabled ? "1" : "0"])
    }

    static func delete(deviceID: Int, subscriptionID: Int) async throws {
        try await post("\(path(deviceID))/\(subscriptionID)/delete", form: [:])
    }

    private static func path(_ deviceID: Int) -> String { "devices/\(deviceID)/subscriptions" }

    private static func request(_ path: String) -> URLRequest {
        var request = URLRequest(url: ServerURL.baseURL.appendingPathComponent(path),
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func post(_ path: String, form: [String: String]) async throws {
        var request = request(path)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        let (data, status) = try await send(request)
        guard (200..<300).contains(status) else { throw rejection(data) }
    }

    private static func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw SubscriptionClientError.invalidResponse
        }
        return (data, status)
    }

    private static func rejection(_ data: Data) -> SubscriptionClientError {
        struct Failure: Decodable { let error: String }
        guard let failure = try? JSONDecoder().decode(Failure.self, from: data) else { return .invalidResponse }
        return .rejected(failure.error)
    }
}
