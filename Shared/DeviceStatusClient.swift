import Foundation

/// Reads and creates this installation's device row.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let registered: Bool
        let name: String?
        /// Server device row for `/devices/:id` routes; present only when registered.
        let id: Int?
    }

    private struct RegisterResponse: Decodable {
        let id: Int
    }

    static func fetch(device: String) async -> DeviceStatus? {
        let url = ServerURL.baseURL.appendingPathComponent("devices/status/\(device)")
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        return try? JSONDecoder().decode(DeviceStatus.self, from: data)
    }

    /// Creates this installation's device row if missing (`POST /devices`) and returns its ID.
    static func register(device: String) async -> Int? {
        var request = URLRequest(url: ServerURL.baseURL.appendingPathComponent("devices"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["device": device])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        return try? JSONDecoder().decode(RegisterResponse.self, from: data).id
    }
}
