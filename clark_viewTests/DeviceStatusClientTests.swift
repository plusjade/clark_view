import Foundation
import Testing
@testable import clark_view

@MainActor
struct DeviceStatusClientTests {
    @Test func unknownInstallRemainsUnpaired() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":false}"#)
        #expect(!status.paired)
        #expect(status.sources == nil)
    }

    @Test func registeredDeviceCanHaveNoAssignments() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":true,"name":null,"sources":[]}"#)
        #expect(status.paired)
        #expect(status.sources?.isEmpty == true)
    }

    @Test func associationsPreserveDuplicateKindsAndSourceOwnedSettings() throws {
        let status = try decode("""
        {"deviceId":"test-install","registered":true,"name":"Example","sources":[
          {"kind":"example","settings":{"choices":["one","two"],"enabled":false}},
          {"kind":"example","settings":{"nested":{"count":2,"value":null},"choices":[]}},
          {"kind":"another-source","settings":{}}
        ]}
        """)
        #expect(status.paired)
        let sources = try #require(status.sources)
        #expect(sources.map(\.kind) == ["example", "example", "another-source"])
        let first = try #require(JSONSerialization.jsonObject(
            with: Data(sources[0].settingsDescription.utf8)
        ) as? [String: Any])
        #expect(first["choices"] as? [String] == ["one", "two"])
        #expect(first["enabled"] as? Bool == false)
        #expect(sources[1].settingsDescription.contains("null"))
        let empty = try #require(JSONSerialization.jsonObject(
            with: Data(sources[2].settingsDescription.utf8)
        ) as? [String: Any])
        #expect(empty.isEmpty)
    }

    @Test func missingRegistrationDoesNotBecomeUnpaired() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"deviceId":"test-install","sources":[]}"#)
        }
    }

    private func decode(_ json: String) throws -> DeviceStatusClient.DeviceStatus {
        try JSONDecoder().decode(DeviceStatusClient.DeviceStatus.self, from: Data(json.utf8))
    }
}
