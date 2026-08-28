//
//  PushTokenClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Uploads this install's APNs device token so the server can force a widget
/// refresh (`POST /device/token`) when the paired config changes from a
/// browser — see `AppDelegate`, which calls this on every
/// `didRegisterForRemoteNotificationsWithDeviceToken`. Fire-and-forget: a
/// failed upload just means the next silent push misses this device until
/// the token re-registers, never a user-visible error.
///
/// KNOWN GAP (2026-08-28): confirmed `/device/token` 404s on jade.beer (curl
/// -X POST) the same way `/config/status/:deviceId` already does — see
/// `DeviceStatusClient`. Hits val.run directly, same workaround, until
/// jade.beer's domain-side staleness is sorted out.
enum PushTokenClient {
    static func upload(device: String, token: Data) async {
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        var request = URLRequest(url: DeviceStatusClient.diagnosticsBaseURL.appendingPathComponent("device/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["device": device, "token": hexToken])
        _ = try? await URLSession.shared.data(for: request)
    }
}
