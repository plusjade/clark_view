import Foundation
import Testing
@testable import clark_view

struct LiveActivityRequestTests {
    @MainActor @Test func alertIntentIsExplicitOnTheWire() throws {
        let body = LiveActivityClient.Body(
            content: ClarkLiveActivityAttributes.ContentState.sample,
            revision: 3,
            alert: true
        )
        let data = try JSONEncoder().encode(body)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["alert"] as? Bool == true)
        #expect(object["revision"] as? Int == 3)
    }
}
