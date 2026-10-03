import Foundation
import Testing
@testable import clark_view

/// Covers how a saved widget configuration becomes one effective selector, and when a
/// placement shows a prompt instead of events. No network or shared preferences.
@MainActor
struct WidgetSelectionTests {
    @Test func selectionsKeepOnlyPublishedViews() {
        #expect(WidgetSelection(mode: nil, viewIDs: []) == .all)
        #expect(WidgetSelection(mode: .all, viewIDs: ["pv_8"]) == .all)
        #expect(WidgetSelection(mode: .selected, viewIDs: ["pv_8", "pv_10", "pv_8"]) == .selected(["pv_8", "pv_10"]))
        // Legacy list IDs are cleared, not translated.
        #expect(WidgetSelection(mode: .selected, viewIDs: ["8", "pv_10"]) == .selected(["pv_10"]))
        #expect(WidgetSelection(mode: .selected, viewIDs: ["8", "pv_08"]) == .needsLists)
        #expect(WidgetSelection(mode: .selected, viewIDs: []) == .needsLists)
    }

    @Test func aSavedLegacyFeedReadsAsAll() {
        var intent = WidgetFeedIntent()
        #expect(WidgetSelection(intent: intent) == .all)
        intent.feed = WidgetFeedEntity(id: "5", name: "Lunar")
        #expect(WidgetSelection(intent: intent) == .all)
        intent.mode = .selected
        #expect(WidgetSelection(intent: intent) == .needsLists)
        intent.views = [WidgetListEntity(id: "pv_8", name: "Lunar")]
        #expect(WidgetSelection(intent: intent) == .selected(["pv_8"]))
    }

    @Test func onlyTheEffectiveSelectorIsSent() throws {
        let row = 12
        func query(_ selection: WidgetSelection) throws -> [String: String] {
            let items = try #require(selection.eventsQuery)
            let url = ServerURL.deviceEventsURL(deviceRow: row, selector: items, timeZoneIdentifier: "Etc/GMT+8")
            #expect(url.path == "/v2/devices/12/events")
            #expect(url.absoluteString.contains("timeZone=Etc/GMT%2B8"))
            let parsed = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return Dictionary(uniqueKeysWithValues: parsed.filter { $0.name != "timeZone" }
                .map { ($0.name, $0.value ?? "") })
        }
        #expect(try query(.all).isEmpty)
        #expect(try query(.selected(["pv_8", "pv_10"])) == ["viewIds": "pv_8,pv_10"])
        // Selected with nothing chosen makes no request at all, so it can never read as All.
        #expect(WidgetSelection.needsLists.eventsQuery == nil)
    }

    @Test func promptsSeparateAnEmptySelectionFromNoEventsAndFromFailure() {
        #expect(WidgetSelection.needsLists.prompt(resolvedViewIDs: nil, feedUnavailable: false) == .chooseLists)
        #expect(WidgetSelection.all.prompt(resolvedViewIDs: [], feedUnavailable: false) == .joinList)
        let subset = WidgetSelection.selected(["pv_8"])
        #expect(subset.prompt(resolvedViewIDs: [], feedUnavailable: false) == .editSelection)
        #expect(subset.prompt(resolvedViewIDs: ["pv_8"], feedUnavailable: false) == nil)
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

    @Test func listCatalogKeepsNamesAfterLeaving() throws {
        let suite = "WidgetSelectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let lists = WidgetListCatalog(defaults: defaults)
        lists.replaceJoined([EventList(id: "8", name: "Lunar")])
        lists.recordJoin(EventList(id: "10", name: "Rams"))
        lists.recordLeave("8")
        #expect(lists.joined == [EventList(id: "10", name: "Rams")])
        #expect(lists.resolve("8").name == "Lunar")
        #expect(lists.resolve("99").name == "View 99")
    }
}
