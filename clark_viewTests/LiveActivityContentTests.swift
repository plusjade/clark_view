import Foundation
import Testing
@testable import clark_view

/// ActivityKit and the server must exchange the same complete, event-independent snapshot.
struct LiveActivityContentTests {
    @Test func activityContentWireContract() throws {
        let json = Data("""
        {"title":"An evening out","message":"Ready when you are","status":"Ready","progress":null}
        """.utf8)
        let content = try JSONDecoder().decode(ClarkLiveActivityAttributes.ContentState.self, from: json)
        #expect(content.isValid)
        #expect(content.progress == nil)
        let encoded = try JSONEncoder().encode(content)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(object.keys) == ["title", "message", "status", "progress"])
        #expect(object["progress"] is NSNull)
        #expect(try JSONDecoder().decode(ClarkLiveActivityAttributes.ContentState.self, from: encoded) == content)
    }
}
