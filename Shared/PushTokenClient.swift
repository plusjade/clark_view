//
//  PushTokenClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Mirrors WidgetKit's push token lifecycle to the server. Uploads are fire-and-forget:
/// timeline refreshes remain the reliability path when registration or delivery fails.
enum PushTokenClient {
    private struct Upload: Encodable {
        let device: String
        let token: String
        let kind: String
        let environment: String
        let active: Bool
    }

    static func updateWidgetToken(device: String, token: Data, active: Bool) async {
        guard let environment = PushEnvironment.current else { return }
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        var request = URLRequest(url: GameDataURL.baseURL.appendingPathComponent("device/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Upload(
            device: device,
            token: hexToken,
            kind: "widget",
            environment: environment,
            active: active
        ))
        _ = try? await URLSession.shared.data(for: request)
    }
}
