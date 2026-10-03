import Foundation

/// The producer's check-in record for a view: maintenance evidence, never a statement
/// that its events are accurate or complete.
struct ViewFreshness: Decodable, Hashable {
    let status: String

    /// The producer has missed at least one declared check, so events may be out of date.
    var isLapsed: Bool { status == "overdue" || status == "stale" }
}

/// A published view from the directory or its detail read.
struct ListSummary: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let freshness: ViewFreshness
    /// Present on a single view's detail; agents read and edit the view through it.
    let stateUrl: URL?

    var list: EventList { EventList(id: id, name: name) }
}

/// A published view this device has joined.
struct JoinedList: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let freshness: ViewFreshness

    var list: EventList { EventList(id: id, name: name) }
}

/// JSON client for the list directory and this device's memberships.
/// `deviceID` is the server's numeric device row.
enum ListClient {
    struct Memberships: Decodable {
        let views: [JoinedList]
    }

    static func directory() async throws -> [ListSummary] {
        struct Directory: Decodable { let views: [ListSummary] }
        let (data, status) = try await send(URLRequest(url: ServerURL.viewsURL,
                                                       cachePolicy: .reloadIgnoringLocalCacheData))
        guard status == 200 else { throw rejection(data) }
        return try JSONDecoder().decode(Directory.self, from: data).views
    }

    static func detail(id: String) async throws -> ListSummary {
        let (data, status) = try await send(URLRequest(url: ServerURL.viewURL(id),
                                                       cachePolicy: .reloadIgnoringLocalCacheData))
        guard status == 200 else { throw rejection(data) }
        return try JSONDecoder().decode(ListSummary.self, from: data)
    }

    static func memberships(deviceID: Int) async throws -> Memberships {
        let (data, status) = try await send(URLRequest(url: ServerURL.deviceViewsURL(deviceRow: deviceID),
                                                       cachePolicy: .reloadIgnoringLocalCacheData))
        guard status == 200 else { throw rejection(data) }
        return try JSONDecoder().decode(Memberships.self, from: data)
    }

    static func join(deviceID: Int, listID: String) async throws {
        try await mutate("PUT", deviceID: deviceID, listID: listID)
    }

    static func leave(deviceID: Int, listID: String) async throws {
        try await mutate("DELETE", deviceID: deviceID, listID: listID)
    }

    private static func mutate(_ method: String, deviceID: Int, listID: String) async throws {
        var request = URLRequest(url: ServerURL.deviceViewsURL(deviceRow: deviceID).appendingPathComponent(listID))
        request.httpMethod = method
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
        switch failure.error {
        case "view_not_found": return .rejected("This view is no longer available.")
        case "not_joined": return .rejected("This view is no longer joined.")
        default: return .invalidResponse
        }
    }
}
