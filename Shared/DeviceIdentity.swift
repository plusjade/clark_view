//
//  DeviceIdentity.swift
//  Shared
//
//  Created by Jade Dominguez on 8/28/26.
//

import Foundation

/// Stable per-install identity, shared between the app and widget extension via an
/// App Group so both processes resolve the same server-side configuration. Never
/// shown to the person using the device — it's only what `/pair` binds and what
/// `/config/resolve` looks up.
enum DeviceIdentity {
    private static let appGroupID = "group.plusjade.clark-view"
    private static let deviceIDKey = "deviceID"
    private static let pairedKey = "isPaired"

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

    /// Local cache of whether `/pair` has ever succeeded here — display-only. The
    /// server owns actual pairing state, so this can go stale (re-paired from the
    /// browser, App Group data restored to a new device) and must never gate a
    /// fetch — only which empty-state copy the widget shows.
    static var isPaired: Bool {
        get { defaults.bool(forKey: pairedKey) }
        set { defaults.set(newValue, forKey: pairedKey) }
    }
}
