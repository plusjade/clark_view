import Foundation

/// Reads installation registration; feed selection is independent of this device.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let registered: Bool
        let name: String?
        /// Server device row for `/devices/:id` routes; present only when registered.
        let id: Int?

        var paired: Bool { registered }
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
}
