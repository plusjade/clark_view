import Foundation

/// A list from the public directory. Timing belongs to the list, not the device.
struct ListSummary: Decodable, Hashable, Identifiable {
    struct Management: Decodable, Hashable {
        let version: Int
        let stateUrl: URL
    }

    let id: String
    let name: String
    let description: String
    let reminderLeadSeconds: Int
    /// False while the server withholds the list; it can still be joined.
    let available: Bool
    let management: Management?

    var list: EventList { EventList(id: id, name: name) }
}

/// A joined list and this device's reminder preference for it.
struct JoinedList: Decodable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let reminderLeadSeconds: Int
    let available: Bool
    let remindersEnabled: Bool

    var list: EventList { EventList(id: id, name: name) }
}

/// JSON client for the list directory and this device's memberships.
/// `deviceID` is the server's numeric device row.
enum ListClient {
    struct Memberships: Decodable {
        let views: [JoinedList]
        let delivery: String
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

    static func setReminders(deviceID: Int, listID: String, enabled: Bool) async throws {
        try await mutate("PATCH", deviceID: deviceID, listID: listID,
                         body: try JSONEncoder().encode(["remindersEnabled": enabled]))
    }

    static func leave(deviceID: Int, listID: String) async throws {
        try await mutate("DELETE", deviceID: deviceID, listID: listID)
    }

    private static func mutate(_ method: String, deviceID: Int, listID: String, body: Data? = nil) async throws {
        var request = URLRequest(url: ServerURL.deviceViewsURL(deviceRow: deviceID).appendingPathComponent(listID))
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
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
