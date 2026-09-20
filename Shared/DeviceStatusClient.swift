import Foundation

/// Reads registration and assigned sources; widget content uses the resolver separately.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let registered: Bool
        let name: String?
        let sources: [SourceAssociation]?

        var paired: Bool { registered }
    }

    /// Kind is diagnostic metadata, not identity. Sources have no settings; the
    /// response's retired `settings` key is ignored here.
    struct SourceAssociation: Decodable {
        let kind: String
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
