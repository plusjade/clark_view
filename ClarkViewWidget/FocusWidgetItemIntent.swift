//
//  FocusWidgetItemIntent.swift
//  ClarkViewWidget
//

import AppIntents
import Foundation

/// Persists the item a person promoted in system-v1. WidgetKit reloads the timeline after
/// the intent returns, so the next entry can present that item as the large primary item.
struct FocusWidgetItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Focus Widget Item"

    @Parameter(title: "Item")
    var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        WidgetFocusStore.focus(on: itemID)
        return .result()
    }
}

/// Focus is local presentation state, not part of the server-owned feed or template contract.
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

    static func focus(on itemID: String) {
        focusedItemID = itemID
        // A focus interaction reloads the timeline immediately. This short window also covers
        // multiple instances of the static widget without delaying ordinary server refreshes.
        defaults.set(Date.now.addingTimeInterval(15), forKey: cacheReuseDeadlineKey)
    }

    static func requireNetworkRefresh() {
        defaults.removeObject(forKey: cacheReuseDeadlineKey)
    }
}
