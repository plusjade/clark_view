import Foundation

/// Joined lists the app publishes for the widget editor's Selected lists picker. Separate
/// from `WidgetFeedCatalog`, which keeps resolving feeds chosen before lists existed.
/// Remembered names outlive membership so a stored selection still resolves offline.
struct WidgetListCatalog {
    static var shared: WidgetListCatalog {
        WidgetListCatalog(defaults: UserDefaults(suiteName: DeviceIdentity.appGroupID) ?? .standard)
    }

    private struct Snapshot: Codable {
        var joined: [EventList] = []
        var names: [String: String] = [:]
    }

    /// V2 holds only published views; the V1 snapshot of legacy lists is abandoned, not migrated.
    private static let key = "widgetListCatalogV2"
    let defaults: UserDefaults

    private var snapshot: Snapshot {
        guard let data = defaults.data(forKey: Self.key),
              let value = try? JSONDecoder().decode(Snapshot.self, from: data) else { return Snapshot() }
        return value
    }

    var joined: [EventList] { snapshot.joined }

    func resolve(_ id: String) -> EventList {
        EventList(id: id, name: snapshot.names[id] ?? "View \(id)")
    }

    func replaceJoined(_ lists: [EventList]) {
        var value = snapshot
        value.joined = lists
        for list in lists { value.names[list.id] = list.name }
        save(value)
    }

    func recordJoin(_ list: EventList) {
        var lists = joined.filter { $0.id != list.id }
        lists.append(list)
        replaceJoined(lists)
    }

    func recordLeave(_ id: String) {
        replaceJoined(joined.filter { $0.id != id })
    }

    private func save(_ value: Snapshot) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
