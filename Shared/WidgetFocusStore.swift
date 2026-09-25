import Foundation

/// Beacon focus and its short interaction cache window are shared by widgets showing
/// the same feed. A different feed never inherits either state.
enum WidgetFocusStore {
    private static let refreshCutoffKey = "beaconRefreshCutoff"
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    private static func key(_ prefix: String, feedID: String) -> String {
        prefix + Data(feedID.utf8).base64EncodedString()
    }

    static func shouldReuseCachedPayload(for feedID: String) -> Bool {
        let deadline = defaults.object(forKey: key("beaconCacheDeadline:", feedID: feedID)) as? Date
        let cutoff = defaults.object(forKey: refreshCutoffKey) as? Date ?? .distantPast
        return deadline.map { $0 > .now && $0.addingTimeInterval(-15) > cutoff } ?? false
    }

    static func focusedItemID(for feedID: String) -> String? {
        defaults.string(forKey: key("beaconFocusedItem:", feedID: feedID))
    }

    static func handleTap(on itemID: String, in feedID: String, changesFocus: Bool) {
        if changesFocus {
            defaults.set(itemID, forKey: key("beaconFocusedItem:", feedID: feedID))
        }
        defaults.set(Date.now.addingTimeInterval(15), forKey: key("beaconCacheDeadline:", feedID: feedID))
    }

    static func requireNetworkRefresh() {
        defaults.set(Date.now, forKey: refreshCutoffKey)
    }

    static func clear(for feedID: String) {
        defaults.removeObject(forKey: key("beaconFocusedItem:", feedID: feedID))
        defaults.removeObject(forKey: key("beaconCacheDeadline:", feedID: feedID))
    }
}
