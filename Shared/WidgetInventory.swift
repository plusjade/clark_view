import Foundation
import WidgetKit

/// One placed widget as reported to `/device/widget-inventory`. Placements have no stable
/// identity, so duplicates are meaningful and preserved.
nonisolated struct WidgetInventoryEntry: Codable, Equatable {
    enum State: String, Codable {
        case configured, unconfigured, unreadable
    }

    let kind: String
    let family: String
    let state: State
    /// Set only for a feed retained from before lists; a list selection never invents one.
    let feedId: String?
    let mode: String?
    let viewIds: [String]?

    init(kind: String, family: String, intent: WidgetFeedIntent?) {
        self.init(kind: kind, family: family, selection: intent.map(WidgetSelection.init(intent:)))
    }

    init(kind: String, family: String, selection: WidgetSelection?) {
        self.kind = kind
        self.family = family
        switch selection {
        case .all:
            (state, feedId, mode, viewIds) = (.configured, nil, "all", nil)
        case .selected(let ids):
            (state, feedId, mode, viewIds) = (.configured, nil, "selected", ids)
        case .legacyFeed(let feed):
            (state, feedId, mode, viewIds) = (.configured, feed.id, "feed", nil)
        case .needsLists:
            (state, feedId, mode, viewIds) = (.unconfigured, nil, nil, nil)
        case nil:
            (state, feedId, mode, viewIds) = (.unreadable, nil, nil, nil)
        }
    }
}

/// Last successful upload plus the failure time that gates retries, kept in the App Group
/// so the app and widget extension share one comparison baseline.
nonisolated struct WidgetInventoryReportState: Codable, Equatable {
    var lastUploadedSignature: String?
    var lastSuccessAt: Date?
    var lastFailureAt: Date?
}

nonisolated enum WidgetInventoryPolicy {
    static let refreshInterval: TimeInterval = 24 * 60 * 60
    static let retryCooldown: TimeInterval = 5 * 60

    /// Order-independent comparison of configuration contents; timestamps are excluded.
    static func signature(of entries: [WidgetInventoryEntry]) -> String {
        entries
            .map {
                [$0.kind, $0.family, $0.state.rawValue, $0.feedId ?? "", $0.mode ?? "",
                 ($0.viewIds ?? []).joined(separator: ",")].joined(separator: "\u{1F}")
            }
            .sorted()
            .joined(separator: "\u{1E}")
    }

    static func shouldUpload(signature: String, state: WidgetInventoryReportState, now: Date,
                             ignoringCooldown: Bool = false) -> Bool {
        if !ignoringCooldown, let failure = state.lastFailureAt,
           now.timeIntervalSince(failure) < retryCooldown {
            return false
        }
        guard let success = state.lastSuccessAt, state.lastUploadedSignature == signature else { return true }
        return now.timeIntervalSince(success) >= refreshInterval
    }
}

extension WidgetFamily {
    var inventoryName: String {
        switch self {
        case .systemSmall: "systemSmall"
        case .systemMedium: "systemMedium"
        case .systemLarge: "systemLarge"
        case .systemExtraLarge: "systemExtraLarge"
        case .accessoryCircular: "accessoryCircular"
        case .accessoryRectangular: "accessoryRectangular"
        case .accessoryInline: "accessoryInline"
        @unknown default: "unknown"
        }
    }
}
