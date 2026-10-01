import AppIntents
import Foundation

/// A feed chosen in the editor before lists existed. Retained so those placements keep
/// decoding; feed row IDs remain opaque values throughout the native client.
struct WidgetFeedEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Feed"
    static let defaultQuery = WidgetFeedQuery()

    var id: String
    @Property(title: "Name") var name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WidgetFeedQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WidgetFeedEntity] {
        guard !identifiers.isEmpty else { return [] }
        let catalog = WidgetFeedCatalog.shared
        return identifiers.map { id in
            let feed = catalog.resolve(id)
            return WidgetFeedEntity(id: feed.id, name: feed.name)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [WidgetFeedEntity] {
        WidgetFeedCatalog.shared.joined.map { WidgetFeedEntity(id: $0.id, name: $0.name) }
    }
}

enum WidgetListMode: String, AppEnum {
    case all
    case selected

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Lists"
    static let caseDisplayRepresentations: [WidgetListMode: DisplayRepresentation] = [
        .all: "All my lists",
        .selected: "Selected lists"
    ]
}

struct WidgetListEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "List"
    static let defaultQuery = WidgetListQuery()

    var id: String
    @Property(title: "Name") var name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

/// Reads only the local catalog: intent queries make no network requests.
struct WidgetListQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WidgetListEntity] {
        let catalog = WidgetListCatalog.shared
        return identifiers.map { id in
            let list = catalog.resolve(id)
            return WidgetListEntity(id: list.id, name: list.name)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [WidgetListEntity] {
        WidgetListCatalog.shared.joined.map { WidgetListEntity(id: $0.id, name: $0.name) }
    }
}

/// The type name, widget kind, and `feed` parameter are the saved identity of existing
/// placements; keep all three. `mode` has no default on purpose: a decoded default would
/// read as an explicit choice and override a saved feed.
struct WidgetFeedIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Clark View"
    static var description = IntentDescription(
        "Show all your lists or choose some. Open Clark View to refresh available lists."
    )

    @Parameter(title: "Show")
    var mode: WidgetListMode?

    @Parameter(title: "Lists")
    var lists: [WidgetListEntity]?

    @Parameter(title: "Feed (earlier version)")
    var feed: WidgetFeedEntity?

    /// The retained feed is offered only while it is the effective selection: an explicit
    /// mode supersedes it, and a placement that never had one is never shown the picker.
    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, WidgetListMode.selected) {
            Summary {
                \.$mode
                \.$lists
            }
        } otherwise: {
            When(\.$mode, .equalTo, WidgetListMode.all) {
                Summary {
                    \.$mode
                }
            } otherwise: {
                When(\.$feed, .hasAnyValue) {
                    Summary {
                        \.$mode
                        \.$feed
                    }
                } otherwise: {
                    Summary {
                        \.$mode
                    }
                }
            }
        }
    }

    init() {
        mode = nil
        lists = nil
        feed = nil
    }
}

extension WidgetSelection {
    nonisolated init(intent: WidgetFeedIntent) {
        self.init(mode: intent.mode,
                  listIDs: intent.lists?.map(\.id) ?? [],
                  feed: intent.feed.map { Feed(id: $0.id, name: $0.name) })
    }
}
