@testable import Spotique

final class FakeAuthService: AuthServicing, @unchecked Sendable {
    var sendCodeResult: Result<SendCodeResult, Error> = .failure(APIError.server)
    var verifyResult: Result<VerifyResult, Error> = .failure(APIError.server)
    var completeProfileResult: Result<User, Error> = .failure(APIError.server)

    func sendCode(_ destination: AuthDestination) async throws -> SendCodeResult {
        try sendCodeResult.get()
    }

    func verify(_ destination: AuthDestination, code: String) async throws -> VerifyResult {
        try verifyResult.get()
    }

    func completeProfile(_ input: CompleteProfileInput) async throws -> User {
        try completeProfileResult.get()
    }
}
