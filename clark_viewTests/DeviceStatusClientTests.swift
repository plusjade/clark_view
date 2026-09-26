import Foundation
import Testing
@testable import clark_view

@MainActor
struct DeviceStatusClientTests {
    @Test func unknownInstallRemainsUnpaired() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":false}"#)
        #expect(!status.paired)
        #expect(status.name == nil)
    }

    @Test func registeredDeviceHasIndependentIdentity() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":true,"name":null,"id":7}"#)
        #expect(status.paired)
        #expect(status.name == nil)
        #expect(status.id == 7)
    }

    @Test func legacySourceFieldsDoNotAffectRegistration() throws {
        let status = try decode("""
        {"deviceId":"test-install","registered":true,"name":"Example","sources":[
          {"kind":"example","settings":{"choices":["one","two"],"enabled":false}},
          {"kind":"example","settings":{"nested":{"count":2,"value":null}}},
          {"kind":"another-source"}
        ]}
        """)
        #expect(status.paired)
        #expect(status.name == "Example")
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
