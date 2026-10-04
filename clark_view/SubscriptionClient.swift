import Foundation

/// A feed joined in an earlier version. Its reminders are paused server-side.
struct Subscription: Decodable, Hashable, Identifiable {
    let id: Int
    let feedId: String
    let feedName: String

    var feed: Feed { Feed(id: feedId, name: feedName) }
}

enum ReminderLead {
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

/// Reads the legacy `/devices/:id/subscriptions` index; legacy membership is frozen server-side.
/// `deviceID` is the server's numeric device row, resolved from this installation's status.
enum SubscriptionClient {
    struct Index: Decodable {
        let subscriptions: [Subscription]
    }

    static func index(deviceID: Int) async throws -> Index {
        let (data, status) = try await send(request(path(deviceID)))
        guard status == 200 else { throw rejection(data) }
        return try JSONDecoder().decode(Index.self, from: data)
    }

    private static func path(_ deviceID: Int) -> String { "devices/\(deviceID)/subscriptions" }

    private static func request(_ path: String) -> URLRequest {
        var request = URLRequest(url: ServerURL.baseURL.appendingPathComponent(path),
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
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
