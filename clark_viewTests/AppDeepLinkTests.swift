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

    @Test func viewLinkCarriesOnlyAPublishedViewID() throws {
        let link = try #require(AppDeepLink(url: URL(string: "clarkview://v2/view/pv_15")!))
        #expect(link.kind == .view)
        #expect(link.subjectID == "pv_15")
        #expect(link.url?.absoluteString == "clarkview://v2/view/pv_15")
        #expect(AppDeepLink(url: URL(string: "clarkview://v2/view/15")!) == nil)
        #expect(AppDeepLink(url: URL(string: "clarkview://v2/view/pv_0")!) == nil)
        #expect(AppDeepLink(url: URL(string: "clarkview://v2/view/pv_15?title=Forged")!) == nil)
        // A legacy numeric view link never resolves as a published view.
        #expect(AppDeepLink(url: URL(string: "clarkview://view/15")!) == nil)
    }
}
