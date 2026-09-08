import Foundation
import Testing
@testable import clark_view

struct PushEnvironmentTests {
    @Test func usesProfileEntitlement() throws {
        for (entitlement, expected) in [("development", "sandbox"), ("production", "production")] {
            let plist = try PropertyListSerialization.data(
                fromPropertyList: ["Entitlements": ["aps-environment": entitlement]], format: .xml, options: 0
            )
            var profile = Data([0x30, 0x82, 0xFF])
            profile.append(plist)
            profile.append(Data([0x00, 0xFF]))
            #expect(PushEnvironment.environment(in: profile) == expected)
        }
    }

    @Test func refusesMalformedOrMissingEntitlement() throws {
        #expect(PushEnvironment.environment(in: Data("broken".utf8)) == nil)
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["Entitlements": ["aps-environment": "unknown"]], format: .xml, options: 0
        )
        #expect(PushEnvironment.environment(in: plist) == nil)
    }
}
