import AppIntents
import Foundation
import Testing
@testable import clark_view

/// Covers the persisted app-to-widget catalog boundary without network or shared production preferences.
@MainActor
struct WidgetFeedCatalogTests {
    @Test func configurationHasNoDefaultAndPreservesUnknownIDs() async throws {
        let query = WidgetFeedQuery()
        let defaultFeed = await query.defaultResult()
        #expect(defaultFeed == nil)
        let empty = try await query.entities(for: [])
        #expect(empty.isEmpty)
        let identifier = "legacy-\(UUID().uuidString)"
        let resolved = try await query.entities(for: [identifier])
        #expect(resolved.map(\.id) == [identifier])
        #expect(resolved.first?.name == "Feed \(identifier)")
    }

    @Test func membershipAndResolutionSurviveSeparateReaders() throws {
        let suite = "WidgetFeedCatalogTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let writer = WidgetFeedCatalog(defaults: defaults)
        let reader = WidgetFeedCatalog(defaults: try #require(UserDefaults(suiteName: suite)))
        let first = Feed(id: "a", name: "First")
        let second = Feed(id: "b", name: "Second")

        #expect(reader.joined.isEmpty)
        #expect(reader.resolve("legacy").id == "legacy")
        writer.replaceJoined([first])
        #expect(reader.joined == [first])
        writer.recordJoin(second)
        #expect(reader.joined == [first, second])
        writer.recordLeave(first.id)
        #expect(reader.joined == [second])
        #expect(reader.resolve(first.id) == first)

        let renamed = Feed(id: second.id, name: "Renamed")
        writer.replaceJoined([renamed])
        #expect(reader.resolve(second.id) == renamed)
        writer.replaceJoined([])
        #expect(reader.joined.isEmpty)
        #expect(reader.resolve(second.id) == renamed)
    }
}
