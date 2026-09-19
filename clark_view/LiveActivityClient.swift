import Foundation

/// JSON transport for the standalone activity record; keys and APNs tokens never enter diagnostics text.
enum LiveActivityClient {
    struct Session: Codable {
        let id: String
        let key: String
    }

    struct Record: Decodable {
        let id: String
        let content: ClarkLiveActivityAttributes.ContentState
        let desiredState: String
        let deviceState: String
        let revision: Int
        let tokenRegistered: Bool
        let alertRequested: Bool?
        let deliveryResult: String
        let deliveredRevision: Int?
    }

    struct Body: Encodable {
        var environment: String?
        var content: ClarkLiveActivityAttributes.ContentState?
        var activityId: String?
        var token: String?
        var state: String?
        var revision: Int?
        var alert: Bool?
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func request(_ operation: String, session: Session, body: Body? = nil) async throws -> Record {
        let url = ServerURL.baseURL.appendingPathComponent("live-activities")
            .appendingPathComponent(session.id).appendingPathComponent(operation)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 20
        request.httpMethod = body == nil ? "GET" : "POST"
        request.setValue("Bearer " + session.key, forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(LiveActivityResponse.self, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              result.succeeded, let record = result.record else {
            throw Failure(message: result.reason ?? "Activity request failed")
        }
        return record
    }
}

private struct LiveActivityResponse: Decodable {
    let succeeded: Bool
    let record: LiveActivityClient.Record?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case succeeded = "ok"
        case record, reason
    }
}
