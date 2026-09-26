import Foundation
import Testing
@testable import clark_view

@MainActor
struct DeviceStatusClientTests {
    @Test func unknownInstallRemainsUnregistered() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":false}"#)
        #expect(!status.registered)
        #expect(status.name == nil)
    }

    @Test func registeredDeviceHasIndependentIdentity() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":true,"paired":true,"name":null,"id":7}"#)
        #expect(status.registered)
        #expect(status.name == nil)
        #expect(status.id == 7)
    }

    @Test func selfRegisteredDeviceHasIdentity() throws {
        let status = try decode(#"{"deviceId":"test-install","registered":true,"paired":false,"id":8}"#)
        #expect(status.registered)
        #expect(status.id == 8)
    }

    @Test func legacySourceFieldsDoNotAffectRegistration() throws {
        let status = try decode("""
        {"deviceId":"test-install","registered":true,"name":"Example","sources":[
          {"kind":"example","settings":{"choices":["one","two"],"enabled":false}},
          {"kind":"example","settings":{"nested":{"count":2,"value":null}}},
          {"kind":"another-source"}
        ]}
        """)
        #expect(status.registered)
        #expect(status.name == "Example")
    }

    @Test func missingRegistrationIsInvalid() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"deviceId":"test-install","sources":[]}"#)
        }
    }

    private func decode(_ json: String) throws -> DeviceStatusClient.DeviceStatus {
        try JSONDecoder().decode(DeviceStatusClient.DeviceStatus.self, from: Data(json.utf8))
    }
}
