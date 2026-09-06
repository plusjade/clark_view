//
//  WidgetFocusStore.swift
//  Shared
//

import Foundation

/// Keeps system-v1's local focus separate from the server-owned feed while allowing
/// explicit refreshes from either target to bypass the short interaction cache.
enum WidgetFocusStore {
    private static let focusedItemIDKey = "systemV1FocusedItemID"
    private static let cacheReuseDeadlineKey = "systemV1CacheReuseDeadline"
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    static var shouldReuseCachedPayload: Bool {
        guard let deadline = defaults.object(forKey: cacheReuseDeadlineKey) as? Date else {
            return false
        }
        return deadline > .now
    }

    static var focusedItemID: String? {
        get { defaults.string(forKey: focusedItemIDKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: focusedItemIDKey)
            } else {
                defaults.removeObject(forKey: focusedItemIDKey)
            }
        }
    }

    static func handleTap(on itemID: String, changesFocus: Bool) {
        if changesFocus {
            focusedItemID = itemID
        }
        // A focus interaction reloads the timeline immediately. This short window also covers
        // captured taps and multiple static widget instances without delaying ordinary refreshes.
        defaults.set(Date.now.addingTimeInterval(15), forKey: cacheReuseDeadlineKey)
    }

    static func requireNetworkRefresh() {
        defaults.removeObject(forKey: cacheReuseDeadlineKey)
    }
}
