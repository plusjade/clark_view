//
//  DeviceStatusClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Prototype-level diagnostics: this device's stored pairing status, straight from
/// `/config/status/:deviceId`. Not part of the receiver's real data path (that's
/// `GameDataURL.resolveURL`) — purely for the paired screen to show what the server
/// actually has on file.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let paired: Bool
        let configId: String?
        let name: String?
        let sports: [String]?
        let teams: [String]?
    }

    // KNOWN GAP (2026-08-28): this route 404s on jade.beer (the custom domain
    // GameDataURL.baseURL points at) while working on the val.run URL — every
    // other route works on both. A per-route val.run fallback was tried and
    // reverted (2026-08-29): keeping two base URLs in sync is more trouble
    // than it's worth, and jade.beer is meant to be the one domain the app
    // ever talks to. Diagnostics just 404s until jade.beer's domain-side
    // staleness is sorted out on the server.
    static func fetch(device: String) async -> DeviceStatus? {
        let url = GameDataURL.baseURL.appendingPathComponent("config/status/\(device)")
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        return try? JSONDecoder().decode(DeviceStatus.self, from: data)
    }
}
