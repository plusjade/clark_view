import AppIntents
import Foundation

/// A feed chosen in the editor before lists existed. Retained only so those placements keep
/// decoding; it no longer selects anything.
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
    func entities(for identifiers: [String]) async throws -> [WidgetFeedEntity] {
        identifiers.map { WidgetFeedEntity(id: $0, name: "Feed \($0)") }
    }

    func suggestedEntities() async throws -> [WidgetFeedEntity] { [] }
}

enum WidgetListMode: String, AppEnum {
    case all
    case selected

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Views"
    static let caseDisplayRepresentations: [WidgetListMode: DisplayRepresentation] = [
        .all: "All my views",
        .selected: "Selected views"
    ]
}

struct WidgetListEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "View"
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
/// placements; keep all three. `mode` has no default so an untouched placement stays
/// distinguishable from an explicit choice.
struct WidgetFeedIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Clark View"
    static var description = IntentDescription(
        "Show all your views or choose some. Open Clark View to refresh available views."
    )

    @Parameter(title: "Show")
    var mode: WidgetListMode?

    @Parameter(title: "Views")
    var views: [WidgetListEntity]?

    @Parameter(title: "Feed (earlier version)")
    var feed: WidgetFeedEntity?

    /// The retained `feed` still decodes but no longer selects anything, so it is never shown.
    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, WidgetListMode.selected) {
            Summary {
                \.$mode
                \.$views
            }
        } otherwise: {
            Summary {
                \.$mode
            }
        }
    }

    init() {
        mode = nil
        views = nil
        feed = nil
    }
}

extension WidgetSelection {
    nonisolated init(intent: WidgetFeedIntent) {
        self.init(mode: intent.mode, viewIDs: intent.views?.map(\.id) ?? [])
    }
}
