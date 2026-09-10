//
//  PushTokenClient.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Mirrors WidgetKit token changes to the server and records registration outcomes
/// separately from timeline fetches, which can succeed without push registration.
enum PushTokenClient {
    private struct Upload: Encodable {
        let device: String
        let token: String
        let kind: String
        let environment: String
        let active: Bool
    }

    static var registrationStatus: String {
        defaults.string(forKey: "widgetPushRegistration") ?? "No WidgetKit token callback recorded"
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard
    }

    private static func record(_ message: String) {
        defaults.set(message, forKey: "widgetPushRegistration")
    }

    static func updateWidgetToken(device: String, token: Data, active: Bool) async {
        record("WidgetKit token received; registering…")
        guard let environment = PushEnvironment.current else {
            record("Token received; signing environment could not be read")
            return
        }
        let hexToken = token.map { String(format: "%02x", $0) }.joined()
        var request = URLRequest(url: ServerURL.baseURL.appendingPathComponent("device/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Upload(
            device: device,
            token: hexToken,
            kind: "widget",
            environment: environment,
            active: active
        ))
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                record("Token upload returned an invalid response")
                return
            }
            if (200..<300).contains(http.statusCode) {
                let action = active ? "Registered" : "Removed"
                let time = Date().formatted(date: .omitted, time: .standard)
                record("\(action) (\(environment)) at \(time)")
            } else {
                record("Token upload failed: HTTP \(http.statusCode)")
            }
        } catch {
            record("Token upload failed: \(error.localizedDescription)")
        }
    }
}
