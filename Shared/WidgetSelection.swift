import Foundation

/// A view this device can join, identified by an opaque published-view ID.
nonisolated struct EventList: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
}

/// Published views carry their API generation in the ID, so a bare legacy number is never
/// one. Shared by deep links and widget selections.
nonisolated enum PublishedViewID {
    static func isValid(_ id: String) -> Bool {
        guard id.hasPrefix("pv_") else { return false }
        let digits = id.dropFirst(3)
        return !digits.isEmpty && digits.count <= 15 && digits.first != "0"
            && digits.allSatisfy { $0.isASCII && $0.isNumber }
    }
}

/// What one widget placement shows, resolved once from its saved configuration so the
/// provider, the request, and the inventory report cannot disagree.
nonisolated enum WidgetSelection: Equatable {
    case all
    case selected([String])
    /// Selected views with nothing chosen. Prompts for an edit; never requests All.
    case needsLists

    /// `mode` stays nil until the user picks one. Selections saved before published views,
    /// including a legacy feed, are cleared rather than translated: they read as All, and
    /// legacy list IDs drop out of a selection.
    init(mode: WidgetListMode?, viewIDs: [String]) {
        switch mode {
        case .selected:
            var seen = Set<String>()
            let unique = viewIDs.filter { PublishedViewID.isValid($0) && seen.insert($0).inserted }
            self = unique.isEmpty ? .needsLists : .selected(unique)
        case .all, nil:
            self = .all
        }
    }

    /// The effective selector for `/v2/devices/:id/events`, or nil when no request may be made.
    var eventsQuery: [URLQueryItem]? {
        switch self {
        case .all: return []
        case .selected(let ids): return [URLQueryItem(name: "viewIds", value: ids.joined(separator: ","))]
        case .needsLists: return nil
        }
    }

    /// The message to show instead of events, or nil to render them (including none).
    /// `resolvedViewIDs` is the server's answer and is nil when a fetch failed, so a
    /// network or identity failure never reads as an empty selection.
    func prompt(resolvedViewIDs: [String]?, feedUnavailable: Bool) -> WidgetPrompt? {
        if self == .needsLists { return .chooseLists }
        if feedUnavailable { return .feedUnavailable }
        guard let resolvedViewIDs, resolvedViewIDs.isEmpty else { return nil }
        switch self {
        case .all: return .joinList
        case .selected: return .editSelection
        case .needsLists: return nil
        }
    }
}

nonisolated enum WidgetPrompt: Equatable {
    case chooseLists
    case joinList
    case editSelection
    case feedUnavailable

    var text: String {
        switch self {
        case .chooseLists: "Long Press\n→ Edit Widget\n→ Choose Views"
        case .joinList: "No views joined\nOpen Clark View to join one."
        case .editSelection: "Selected views unavailable\nLong press to edit widget & choose views."
        case .feedUnavailable: "Feed unavailable\nLong press to edit widget & choose views."
        }
    }
}
