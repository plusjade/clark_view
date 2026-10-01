import Foundation

/// A list this device can join: one server source, identified by an opaque ID.
nonisolated struct EventList: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
}

/// What one widget placement shows, resolved once from its saved configuration so the
/// provider, the request, and the inventory report cannot disagree.
nonisolated enum WidgetSelection: Equatable {
    case all
    case selected([String])
    /// Selected lists with nothing chosen. Prompts for an edit; never requests All.
    case needsLists
    /// A feed chosen before lists existed. The server resolves it; the ID is never a list ID.
    case legacyFeed(Feed)

    /// Precedence: an explicit mode, then a retained feed, then All. `mode` stays nil until
    /// the user picks one, which is what keeps a saved feed distinct from explicit All.
    init(mode: WidgetListMode?, listIDs: [String], feed: Feed?) {
        switch mode {
        case .all:
            self = .all
        case .selected:
            var seen = Set<String>()
            let unique = listIDs.filter { seen.insert($0).inserted }
            self = unique.isEmpty ? .needsLists : .selected(unique)
        case nil:
            self = feed.map(WidgetSelection.legacyFeed) ?? .all
        }
    }

    /// The effective selector for `/devices/:id/events`, or nil when no request may be made.
    /// Only one selector is ever sent; an explicit mode supersedes a retained feed.
    var eventsQuery: [URLQueryItem]? {
        switch self {
        case .all: return []
        case .selected(let ids): return [URLQueryItem(name: "listIds", value: ids.joined(separator: ","))]
        case .needsLists: return nil
        case .legacyFeed(let feed): return [URLQueryItem(name: "feedId", value: feed.id)]
        }
    }

    /// The message to show instead of events, or nil to render them (including none).
    /// `resolvedListIDs` is the server's answer and is nil when a fetch failed, so a
    /// network or identity failure never reads as an empty selection.
    func prompt(resolvedListIDs: [String]?, feedUnavailable: Bool) -> WidgetPrompt? {
        if self == .needsLists { return .chooseLists }
        if feedUnavailable { return .feedUnavailable }
        guard let resolvedListIDs, resolvedListIDs.isEmpty else { return nil }
        switch self {
        case .all: return .joinList
        case .selected: return .editSelection
        case .needsLists, .legacyFeed: return nil
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
        case .chooseLists: "Long Press\n→ Edit Widget\n→ Choose Lists"
        case .joinList: "No lists joined\nOpen Clark View to join one."
        case .editSelection: "Selected lists unavailable\nLong press to edit widget & choose lists."
        case .feedUnavailable: "Feed unavailable\nLong press to edit widget & choose lists."
        }
    }
}
