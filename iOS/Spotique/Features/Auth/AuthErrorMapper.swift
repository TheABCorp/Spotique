import Foundation

/// The auth request that failed; the same status means different things per step.
nonisolated enum AuthStep: Sendable {
    case sendCode
    case verify
    case completeProfile
}

/// A user-facing auth failure. Views show `message`; ViewModels switch on
/// the case to decide recovery (clear the code, enable resend, highlight fields).
nonisolated enum AuthFailure: Equatable, Sendable {
    case invalidDestination
    case rateLimited
    case invalidCode
    case codeExpired
    case tooManyAttempts
    case invalidFields([String: [String]])
    case profileAlreadyCompleted
    case offline
    case generic

    var message: String {
        switch self {
        case .invalidDestination:
            String(localized: "That phone number or email isn't valid. Check it and try again.")
        case .rateLimited:
            String(localized: "Too many requests. Please try again later.")
        case .invalidCode:
            String(localized: "Invalid code. Please try again.")
        case .codeExpired:
            String(localized: "Code expired. Please request a new one.")
        case .tooManyAttempts:
            String(localized: "Too many attempts. Request a new code.")
        case .invalidFields:
            String(localized: "Please fix the highlighted fields.")
        case .profileAlreadyCompleted:
            String(localized: "Your profile is already set up. Please sign in again.")
        case .offline:
            String(localized: "No internet connection. Please try again.")
        case .generic:
            String(localized: "Something went wrong. Please try again.")
        }
    }
}

nonisolated enum AuthErrorMapper {
    /// Rails returns 401 for both a wrong code and a missing/expired one, with
    /// no `error.code` to tell them apart, so the expired case is recognized by
    /// its message. Replace this once the API adds error codes.
    private static let expiredCodeMessagePrefix = "No active verification code"

    static func failure(for error: any Error, step: AuthStep) -> AuthFailure {
        guard let apiError = error as? APIError else { return .generic }

        switch (apiError, step) {
        case (.offline, _):
            return .offline
        case (.rateLimited, .verify):
            return .tooManyAttempts
        case (.rateLimited, _):
            return .rateLimited
        case (.validation, .sendCode), (.unknown(statusCode: 400), .sendCode):
            return .invalidDestination
        case let (.unauthorized(message), .verify):
            let isExpired = message?.hasPrefix(expiredCodeMessagePrefix) == true
            return isExpired ? .codeExpired : .invalidCode
        case let (.validation(_, fields), .completeProfile):
            return .invalidFields(fields)
        case (.conflict, .completeProfile):
            return .profileAlreadyCompleted
        default:
            return .generic
        }
    }
}
