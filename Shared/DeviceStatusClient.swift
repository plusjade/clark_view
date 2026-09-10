import Foundation

/// Reads registration and assigned source settings; widget content uses the resolver separately.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let registered: Bool
        let name: String?
        let sources: [SourceAssociation]?

        var paired: Bool { registered }
    }

    struct SourceAssociation: Decodable {
        let kind: String
        let settings: SettingsValue

        var settingsDescription: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            guard let data = try? encoder.encode(settings),
                  let text = String(data: data, encoding: .utf8) else { return "Settings unavailable" }
            return text
        }
    }

    /// Source-owned settings remain JSON so diagnostics never depends on a source's domain schema.
    indirect enum SettingsValue: Codable {
        case object([String: SettingsValue])
        case array([SettingsValue])
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if value.decodeNil() {
                self = .null
            } else if let bool = try? value.decode(Bool.self) {
                self = .bool(bool)
            } else if let string = try? value.decode(String.self) {
                self = .string(string)
            } else if let number = try? value.decode(Double.self) {
                self = .number(number)
            } else if let array = try? value.decode([SettingsValue].self) {
                self = .array(array)
            } else {
                self = .object(try value.decode([String: SettingsValue].self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .object(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .string(let value): try container.encode(value)
            case .number(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .null: try container.encodeNil()
            }
        }
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
