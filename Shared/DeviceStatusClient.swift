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
    // GameDataURL.baseURL now points at) while working on the val.run URL —
    // every other route works on both, so hitting val.run directly here until
    // whoever owns jade.beer's setup sorts out the domain-side staleness.
    // Not `private`: PushTokenClient hits the same val.run fallback for
    // `/device/token`, a newer route that 404s on jade.beer the same way —
    // see that file for the confirmed repro.
    static let diagnosticsBaseURL = URL(string: "https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/")!

    static func fetch(device: String) async -> DeviceStatus? {
        let url = diagnosticsBaseURL.appendingPathComponent("config/status/\(device)")
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }
        return try? JSONDecoder().decode(DeviceStatus.self, from: data)
    }
}
