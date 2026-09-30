import AppIntents
import Foundation

/// The widget editor stores one explicit joined feed choice per widget.
/// Feed row IDs remain opaque values throughout the native client.
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

struct WidgetFeedIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Clark View Feed"
    static var description = IntentDescription("Choose a joined feed. Open Clark View to refresh available feeds.")

    @Parameter(title: "Feed")
    var feed: WidgetFeedEntity?

    init() {
        feed = nil
    }
}
