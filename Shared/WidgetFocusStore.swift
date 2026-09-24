//
//  WidgetFocusStore.swift
//  Shared
//

import Foundation

/// Keeps Beacon's local focus separate from the server-owned feed while allowing
/// explicit refreshes from either target to bypass the short interaction cache.
enum WidgetFocusStore {
    private static let focusedItemIDKey = "beaconFocusedItemID"
    private static let cacheReuseDeadlineKey = "beaconCacheReuseDeadline"
    private static let focusFeedIDKey = "beaconFocusFeedID"
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    static var shouldReuseCachedPayload: Bool {
        guard defaults.string(forKey: focusFeedIDKey) == FeedSelection.current?.id else { return false }
        guard let deadline = defaults.object(forKey: cacheReuseDeadlineKey) as? Date else {
            return false
        }
        return deadline > .now
    }

    static var focusedItemID: String? {
        get {
            guard defaults.string(forKey: focusFeedIDKey) == FeedSelection.current?.id else { return nil }
            return defaults.string(forKey: focusedItemIDKey)
        }
        set {
            defaults.set(FeedSelection.current?.id, forKey: focusFeedIDKey)
            if let newValue {
                defaults.set(newValue, forKey: focusedItemIDKey)
            } else {
                defaults.removeObject(forKey: focusedItemIDKey)
            }
        }
    }

    static func handleTap(on itemID: String, changesFocus: Bool) {
        defaults.set(FeedSelection.current?.id, forKey: focusFeedIDKey)
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

    static func clear() {
        defaults.removeObject(forKey: focusedItemIDKey)
        defaults.removeObject(forKey: focusFeedIDKey)
        requireNetworkRefresh()
    }
}
