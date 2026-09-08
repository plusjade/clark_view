import Foundation

/// APNs routing follows signing, independently of the live API URL or Debug configuration.
enum PushEnvironment {
    static var current: String? {
#if targetEnvironment(simulator)
        return "sandbox"
#else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            // App Store distribution removes the embedded provisioning profile.
            return "production"
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return environment(in: data)
#endif
    }

    static func environment(in profile: Data) -> String? {
        guard let start = profile.range(of: Data("<?xml".utf8)),
              let end = profile.range(of: Data("</plist>".utf8), in: start.lowerBound..<profile.endIndex),
              let plist = try? PropertyListSerialization.propertyList(
                from: profile.subdata(in: start.lowerBound..<end.upperBound), options: [], format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let value = entitlements["aps-environment"] as? String else { return nil }
        switch value {
        case "development": return "sandbox"
        case "production": return "production"
        default: return nil
        }
    }
}
