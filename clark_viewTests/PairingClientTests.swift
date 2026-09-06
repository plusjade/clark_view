import Foundation
import Testing
@testable import clark_view

@MainActor
struct PairingClientTests {
    @Test func bunchRegistrationDoesNotRequireLegacyConfigID() {
        let data = Data(#"{"ok":true,"deviceId":123}"#.utf8)
        #expect(PairingClient.interpret(data: data, statusCode: 200) == .paired)
        #expect(PairingClient.interpret(data: Data(#"{"ok":true}"#.utf8), statusCode: 200) == .paired)
    }

    @Test(arguments: [404, 422]) func invalidCodesAreRejected(statusCode: Int) {
        #expect(PairingClient.interpret(data: Data(), statusCode: statusCode) == .invalidOrExpiredCode)
    }

    @Test(arguments: [400, 500, 503]) func serverErrorsPreserveHTTPStatus(statusCode: Int) {
        #expect(PairingClient.interpret(data: Data(), statusCode: statusCode) == .serverError(statusCode: statusCode))
    }

    @Test(arguments: [#"{"ok":false}"#, #"{"deviceId":123}"#, #"{"ok":"true"}"#, "<html>Error</html>"])
    func unexpectedSuccessBodiesAreNotConnectionErrors(body: String) {
        #expect(PairingClient.interpret(data: Data(body.utf8), statusCode: 200) == .invalidResponse)
    }
}
