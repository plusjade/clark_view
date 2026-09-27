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
    func entities(for identifiers: [String]) async throws -> [WidgetFeedEntity] {
        let feeds = try await DeviceFeedClient.joined()
        let feedsByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0) })
        return identifiers.compactMap { id in
            feedsByID[id].map { WidgetFeedEntity(id: $0.id, name: $0.name) }
        }
    }

    func defaultResult() async -> WidgetFeedEntity? {
        guard let lastJoined = WidgetFeedDefault.lastJoined,
              let feeds = try? await DeviceFeedClient.joined(),
              let feed = feeds.first(where: { $0.id == lastJoined.id }) else { return nil }
        return WidgetFeedEntity(id: feed.id, name: feed.name)
    }

    func suggestedEntities() async throws -> [WidgetFeedEntity] {
        let feeds = try await DeviceFeedClient.joined()
        return feeds.map { WidgetFeedEntity(id: $0.id, name: $0.name) }
    }
}

struct WidgetFeedIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Clark View Feed"
    static var description = IntentDescription("Choosing a feed does not subscribe this device to notifications.")

    @Parameter(title: "Feed")
    var feed: WidgetFeedEntity?

    init() {
        feed = nil
    }
}

/// A successful app join seeds new configurations without changing placed widgets.
/// Store the name with the ID while membership remains server-authoritative.
enum WidgetFeedDefault {
    private static let key = "lastJoinedWidgetFeed"
    private static let defaults = UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard

    static var lastJoined: Feed? {
        guard let value = defaults.dictionary(forKey: key),
              let id = value["id"] as? String,
              let name = value["name"] as? String else { return nil }
        return Feed(id: id, name: name)
    }

    static func recordJoin(_ feed: Feed) {
        defaults.set(["id": feed.id, "name": feed.name], forKey: key)
    }
}
