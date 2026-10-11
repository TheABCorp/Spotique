#if DEBUG
import Foundation

/// Canned responses for SwiftUI previews, so they never hit the network.
struct PreviewAuthService: AuthServicing {
    var failure: AuthFailure?

    func sendCode(_ destination: AuthDestination) async throws -> SendCodeResult {
        try throwIfFailing()
        return SendCodeResult(medium: "phone", masked: "+1347***1234", expiresIn: 600)
    }

    func verify(_ destination: AuthDestination, code: String) async throws -> VerifyResult {
        try throwIfFailing()
        return VerifyResult(id: UUID(), token: "preview-token", isNew: true, user: nil)
    }

    func completeProfile(_ input: CompleteProfileInput) async throws -> User {
        try throwIfFailing()
        return User(
            id: UUID(), phone: "+13475551234", email: nil, firstName: input.firstName,
            lastName: input.lastName, role: input.role, addresses: [],
            createdAt: .now, updatedAt: .now
        )
    }

    private func throwIfFailing() throws {
        switch failure {
        case nil: return
        case .offline: throw APIError.offline
        case .rateLimited, .tooManyAttempts: throw APIError.rateLimited
        case .invalidCode: throw APIError.unauthorized(message: "Invalid code. Please try again.")
        case .codeExpired: throw APIError.unauthorized(message: "No active verification code found.")
        default: throw APIError.server
        }
    }
}
#endif
