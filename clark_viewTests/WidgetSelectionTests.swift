import Foundation
import Testing
@testable import clark_view

/// Covers how a saved widget configuration becomes one effective selector, and when a
/// placement shows a prompt instead of events. No network or shared preferences.
@MainActor
struct WidgetSelectionTests {
    private let feed = Feed(id: "5", name: "Lunar")

    @Test func explicitModeSupersedesARetainedFeed() {
        #expect(WidgetSelection(mode: nil, viewIDs: [], feed: nil) == .all)
        #expect(WidgetSelection(mode: nil, viewIDs: ["8"], feed: feed) == .legacyFeed(feed))
        #expect(WidgetSelection(mode: .all, viewIDs: ["8"], feed: feed) == .all)
        #expect(WidgetSelection(mode: .selected, viewIDs: ["8", "10", "8"], feed: feed) == .selected(["8", "10"]))
        #expect(WidgetSelection(mode: .selected, viewIDs: [], feed: feed) == .needsLists)
    }

    @Test func intentWithNothingSavedIsAllAndKeepsASavedFeed() {
        var intent = WidgetFeedIntent()
        #expect(WidgetSelection(intent: intent) == .all)
        intent.feed = WidgetFeedEntity(id: feed.id, name: feed.name)
        #expect(WidgetSelection(intent: intent) == .legacyFeed(feed))
        intent.mode = .selected
        #expect(WidgetSelection(intent: intent) == .needsLists)
        intent.views = [WidgetListEntity(id: "8", name: "Lunar")]
        #expect(WidgetSelection(intent: intent) == .selected(["8"]))
    }

    @Test func onlyTheEffectiveSelectorIsSent() throws {
        let row = 12
        func query(_ selection: WidgetSelection) throws -> [String: String] {
            let items = try #require(selection.eventsQuery)
            let url = ServerURL.deviceEventsURL(deviceRow: row, selector: items, timeZoneIdentifier: "Etc/GMT+8")
            #expect(url.path == "/devices/12/events")
            #expect(url.absoluteString.contains("timeZone=Etc/GMT%2B8"))
            let parsed = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return Dictionary(uniqueKeysWithValues: parsed.filter { $0.name != "timeZone" }
                .map { ($0.name, $0.value ?? "") })
        }
        #expect(try query(.all).isEmpty)
        #expect(try query(.selected(["8", "10"])) == ["viewIds": "8,10"])
        #expect(try query(.legacyFeed(feed)) == ["feedId": "5"])
        // Selected with nothing chosen makes no request at all, so it can never read as All.
        #expect(WidgetSelection.needsLists.eventsQuery == nil)
    }

    @Test func promptsSeparateAnEmptySelectionFromNoEventsAndFromFailure() {
        #expect(WidgetSelection.needsLists.prompt(resolvedViewIDs: nil, feedUnavailable: false) == .chooseLists)
        #expect(WidgetSelection.all.prompt(resolvedViewIDs: [], feedUnavailable: false) == .joinList)
        let subset = WidgetSelection.selected(["8"])
        #expect(subset.prompt(resolvedViewIDs: [], feedUnavailable: false) == .editSelection)
        #expect(subset.prompt(resolvedViewIDs: ["8"], feedUnavailable: false) == nil)
        #expect(WidgetSelection.legacyFeed(feed).prompt(resolvedViewIDs: [], feedUnavailable: false) == nil)
        #expect(WidgetSelection.legacyFeed(feed).prompt(resolvedViewIDs: nil, feedUnavailable: true) == .feedUnavailable)
        // A failed fetch has no server answer: never a join or edit prompt.
        #expect(WidgetSelection.all.prompt(resolvedViewIDs: nil, feedUnavailable: false) == nil)
        #expect(subset.prompt(resolvedViewIDs: nil, feedUnavailable: false) == nil)
    }

    @Test func payloadDecodesSelectionAndToleratesItsAbsence() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let events = Data(#"{"schemaVersion":3,"items":[],"selection":{"mode":"all","viewIds":[]}}"#.utf8)
        #expect(try decoder.decode(WidgetPayload.self, from: events).selection
            == WidgetSelectionSummary(mode: "all", viewIds: []))
        let legacy = Data(#"{"schemaVersion":3,"items":[]}"#.utf8)
        #expect(try decoder.decode(WidgetPayload.self, from: legacy).selection == nil)
    }

    @Test func listCatalogKeepsNamesAfterLeavingAndStaysSeparateFromFeeds() throws {
        let suite = "WidgetSelectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let lists = WidgetListCatalog(defaults: defaults), feeds = WidgetFeedCatalog(defaults: defaults)
        feeds.replaceJoined([feed])
        lists.replaceJoined([EventList(id: "8", name: "Lunar")])
        lists.recordJoin(EventList(id: "10", name: "Rams"))
        lists.recordLeave("8")
        #expect(lists.joined == [EventList(id: "10", name: "Rams")])
        #expect(lists.resolve("8").name == "Lunar")
        #expect(lists.resolve("99").name == "View 99")
        // The list catalog never overwrites the legacy feed catalog.
        #expect(feeds.joined == [feed])
    }
}
