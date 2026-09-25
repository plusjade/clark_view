import Foundation
import Testing
@testable import clark_view

@MainActor
struct WidgetInventoryTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func entry(_ family: String, feed: String?) -> WidgetInventoryEntry {
        var intent = WidgetFeedIntent()
        intent.feed = feed.map { WidgetFeedEntity(id: $0, name: "Feed \($0)") }
        return WidgetInventoryEntry(kind: WidgetKind.configurable, family: family, intent: intent)
    }

    @Test func configurationStatesStayDistinct() throws {
        let data = try JSONEncoder().encode([
            entry("systemSmall", feed: "5"),
            entry("systemLarge", feed: nil),
            WidgetInventoryEntry(kind: WidgetKind.configurable, family: "accessoryRectangular", intent: nil)
        ])
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [[String: String]])
        #expect(json.map { $0["state"] } == ["configured", "unconfigured", "unreadable"])
        #expect(json.map { $0["feedId"] } == ["5", nil, nil])
    }

    @Test func signatureIgnoresOrderButKeepsDuplicates() {
        let small = entry("systemSmall", feed: "5"), large = entry("systemLarge", feed: "7")
        let signature = WidgetInventoryPolicy.signature(of: [small, large])
        #expect(signature == WidgetInventoryPolicy.signature(of: [large, small]))
        #expect(signature != WidgetInventoryPolicy.signature(of: [small, small, large]))
        #expect(signature != WidgetInventoryPolicy.signature(of: [small, entry("systemLarge", feed: "8")]))
        #expect(WidgetInventoryPolicy.signature(of: []) != signature)
    }

    @Test func uploadsWhenNothingHasSucceeded() {
        #expect(WidgetInventoryPolicy.shouldUpload(signature: "", state: .init(), now: now))
    }

    @Test func unchangedSnapshotIsSuppressedUntilDailyRefresh() {
        let state = WidgetInventoryReportState(lastUploadedSignature: "a", lastSuccessAt: now)
        #expect(!WidgetInventoryPolicy.shouldUpload(signature: "a", state: state, now: now.addingTimeInterval(3600)))
        #expect(WidgetInventoryPolicy.shouldUpload(signature: "b", state: state, now: now.addingTimeInterval(60)))
        #expect(WidgetInventoryPolicy.shouldUpload(signature: "a", state: state, now: now.addingTimeInterval(86_400)))
    }

    @Test func failureCooldownAppliesUnlessPairing() {
        let state = WidgetInventoryReportState(lastUploadedSignature: "a", lastSuccessAt: now,
                                               lastFailureAt: now.addingTimeInterval(100))
        #expect(!WidgetInventoryPolicy.shouldUpload(signature: "b", state: state, now: now.addingTimeInterval(200)))
        #expect(WidgetInventoryPolicy.shouldUpload(signature: "b", state: state, now: now.addingTimeInterval(200),
                                                   ignoringCooldown: true))
        #expect(WidgetInventoryPolicy.shouldUpload(signature: "b", state: state, now: now.addingTimeInterval(400)))
    }
}
