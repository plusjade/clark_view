//
//  DeviceIdentity.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Stable per-install identity, shared between the app and widget extension via an
/// App Group so widget selection and push tokens share the installation identity.
enum DeviceIdentity {
    static let appGroupID = "group.plusjade.clark-view"
    private static let deviceIDKey = "deviceID"

    // Falls back to .standard if the App Group entitlement isn't provisioned yet
    // (e.g. before Xcode has synced the capability with the signing team) — the app
    // still works, it just doesn't share identity with the widget extension until then.
    private static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    static var deviceID: String {
        if let existing = defaults.string(forKey: deviceIDKey) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: deviceIDKey)
        return generated
    }

}
