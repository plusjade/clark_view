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
    let feedId: String?

    init(kind: String, family: String, intent: WidgetFeedIntent?) {
        self.kind = kind
        self.family = family
        if let intent {
            feedId = intent.feed?.id
            state = feedId == nil ? .unconfigured : .configured
        } else {
            feedId = nil
            state = .unreadable
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
            .map { [$0.kind, $0.family, $0.state.rawValue, $0.feedId ?? ""].joined(separator: "\u{1F}") }
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
