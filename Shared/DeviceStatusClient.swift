import Foundation

private enum DeviceStatusKeys: String, CodingKey {
    case deviceId, registered, paired, name, id
}

/// Reads and creates this installation's device row. Pairing (bunch membership) is optional.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let registered: Bool
        /// Bunch membership; older servers omit it and treat every registered device as paired.
        let paired: Bool
        let name: String?
        /// Server device row for `/devices/:id` routes; present only when registered.
        let id: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DeviceStatusKeys.self)
            deviceId = try container.decode(String.self, forKey: .deviceId)
            registered = try container.decode(Bool.self, forKey: .registered)
            paired = try container.decodeIfPresent(Bool.self, forKey: .paired) ?? registered
            name = try container.decodeIfPresent(String.self, forKey: .name)
            id = try container.decodeIfPresent(Int.self, forKey: .id)
        }
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

    /// Creates this installation's unpaired device row if missing (`POST /devices`) and returns its ID.
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
