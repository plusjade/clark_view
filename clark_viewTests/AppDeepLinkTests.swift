import Foundation
import Testing
@testable import clark_view

struct AppDeepLinkTests {
    @Test func subjectRoundTripsThroughURL() throws {
        let destination = AppDeepLink(
            kind: .event,
            subjectID: "12:event/7",
            title: "Fever @ Wings",
            detail: "ESPN 263 · DirecTV",
            startsAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let url = try #require(destination.url)
        let decoded = try #require(AppDeepLink(url: url))

        #expect(decoded == destination)
    }

    @Test func rejectsForeignAndIncompleteURLs() {
        #expect(AppDeepLink(url: URL(string: "https://example.com/event/1")!) == nil)
        #expect(AppDeepLink(url: URL(string: "clarkview://event/1")!) == nil)
    }
}
