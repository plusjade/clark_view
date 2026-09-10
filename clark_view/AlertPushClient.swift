import Foundation

/// Synchronizes visible-alert permission and sends a fixed self-test through the live server.
enum AlertPushClient {
    private struct Request: Encodable {
        let device: String
        let token: String
        let environment: String
        let allowed: Bool
    }

    static func send(token: String, allowed: Bool, test: Bool = false) async throws -> String {
        guard let environment = PushEnvironment.current else {
            throw Failure(message: "Couldn't determine the signed APNs environment.")
        }
        let path = "device/notifications/" + (test ? "test" : "register")
        var request = URLRequest(url: ServerURL.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(
            device: DeviceIdentity.deviceID, token: token, environment: environment, allowed: allowed
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        let result = try JSONDecoder().decode(AlertPushResponse.self, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), result.succeeded else {
            throw Failure(message: result.reason ?? "Server registration failed. Please retry.")
        }
        return test ? "Accepted by Apple; check your notifications." : "Synced with server (\(environment))"
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}

private struct AlertPushResponse: Decodable {
    let succeeded: Bool
    enum CodingKeys: String, CodingKey {
        case succeeded = "ok"
        case reason
    }
    let reason: String?
}
