//
//  DeviceStatusClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Prototype-level diagnostics read this device's stored registration and primary
/// source straight from `/config/status/:deviceId`. Not part of the receiver's real data path (that's
/// `GameDataURL.resolveURL`) — purely for the paired screen to show what the server
/// actually has on file.
enum DeviceStatusClient {
    struct DeviceStatus: Decodable {
        let deviceId: String
        let paired: Bool
        let activeSource: String?
        let name: String?
        let sports: [String]?
        let teams: [String]?
    }

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
