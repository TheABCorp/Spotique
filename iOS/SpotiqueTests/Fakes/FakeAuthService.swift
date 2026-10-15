import Foundation
import Synchronization
@testable import Spotique

/// Returns configurable results and records every call, so ViewModel tests
/// can assert what was sent (and how many times).
final class FakeAuthService: AuthServicing {
    private struct State {
        var sendCodeResult: Result<SendCodeResult, any Error> = .failure(APIError.server)
        var verifyResult: Result<VerifyResult, any Error> = .failure(APIError.server)
        var completeProfileResult: Result<User, any Error> = .failure(APIError.server)
        var sentDestinations: [AuthDestination] = []
        var verifiedCodes: [String] = []
        var completedProfiles: [CompleteProfileInput] = []
    }

    private let state = Mutex(State())

    var sendCodeResult: Result<SendCodeResult, any Error> {
        get { state.withLock { $0.sendCodeResult } }
        set { state.withLock { $0.sendCodeResult = newValue } }
    }

    var verifyResult: Result<VerifyResult, any Error> {
        get { state.withLock { $0.verifyResult } }
        set { state.withLock { $0.verifyResult = newValue } }
    }

    var completeProfileResult: Result<User, any Error> {
        get { state.withLock { $0.completeProfileResult } }
        set { state.withLock { $0.completeProfileResult = newValue } }
    }

    var sentDestinations: [AuthDestination] { state.withLock { $0.sentDestinations } }
    var verifiedCodes: [String] { state.withLock { $0.verifiedCodes } }
    var completedProfiles: [CompleteProfileInput] { state.withLock { $0.completedProfiles } }

    func sendCode(_ destination: AuthDestination) async throws -> SendCodeResult {
        try state.withLock {
            $0.sentDestinations.append(destination)
            return try $0.sendCodeResult.get()
        }
    }

    func verify(_ destination: AuthDestination, code: String) async throws -> VerifyResult {
        try state.withLock {
            $0.verifiedCodes.append(code)
            return try $0.verifyResult.get()
        }
    }

    func completeProfile(_ input: CompleteProfileInput) async throws -> User {
        try state.withLock {
            $0.completedProfiles.append(input)
            return try $0.completeProfileResult.get()
        }
    }
}
