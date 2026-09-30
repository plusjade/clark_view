import Foundation

/// The app publishes picker choices; the widget only reads this App Group snapshot.
/// Remembered names outlive membership so placed widgets keep resolving offline.
struct WidgetFeedCatalog {
    static var shared: WidgetFeedCatalog {
        WidgetFeedCatalog(defaults: UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard)
    }

    private struct Snapshot: Codable {
        var joined: [Feed] = []
        var names: [String: String] = [:]
    }

    private static let key = "widgetFeedCatalogV1"
    let defaults: UserDefaults

    private var snapshot: Snapshot {
        guard let data = defaults.data(forKey: Self.key),
              let value = try? JSONDecoder().decode(Snapshot.self, from: data) else { return Snapshot() }
        return value
    }

    var joined: [Feed] { snapshot.joined }

    func resolve(_ id: String) -> Feed {
        // Older placements may predate the catalog. Keep their IDs usable until a name is known.
        Feed(id: id, name: snapshot.names[id] ?? "Feed \(id)")
    }

    func replaceJoined(_ feeds: [Feed]) {
        var value = snapshot
        value.joined = feeds
        for feed in feeds { value.names[feed.id] = feed.name }
        save(value)
    }

    func recordJoin(_ feed: Feed) {
        var feeds = joined.filter { $0.id != feed.id }
        feeds.append(feed)
        replaceJoined(feeds)
    }

    func recordLeave(_ id: String) {
        replaceJoined(joined.filter { $0.id != id })
    }

    private func save(_ value: Snapshot) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
