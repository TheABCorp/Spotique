import Foundation
import OSLog

/// A code was sent; the verification screen needs to know where.
nonisolated struct PendingVerification: Hashable, Identifiable, Sendable {
    let destination: AuthDestination
    /// Masked as returned by the API, e.g. `+1347***1234`. Display as-is.
    let maskedDestination: String

    var id: Self { self }
}

/// First auth step: choose phone or email and request a 6-digit code.
/// Sign-up and sign-in share this flow; verify decides which it was.
@Observable
@MainActor
final class AuthStartViewModel {
    enum State: Equatable {
        case idle
        case sending
        case failed(AuthFailure)
    }

    var selectedMedium: AuthMedium = .phone {
        didSet {
            guard selectedMedium != oldValue, case .failed = state else { return }
            state = .idle
        }
    }
    var phoneInput = ""
    var emailInput = ""
    var pendingVerification: PendingVerification?
    private(set) var state: State = .idle

    private let authService: any AuthServicing

    init(authService: any AuthServicing) {
        self.authService = authService
    }

    /// Re-derived from the input so edits always invalidate it.
    var destination: AuthDestination? {
        switch selectedMedium {
        case .phone: .phone(fromInput: phoneInput)
        case .email: .email(fromInput: emailInput)
        }
    }

    var canSubmit: Bool {
        destination != nil && state != .sending
    }

    var failure: AuthFailure? {
        if case .failed(let failure) = state { failure } else { nil }
    }

    func sendCode() async {
        guard let destination, state != .sending else { return }
        state = .sending

        do {
            let result = try await authService.sendCode(destination)
            state = .idle
            pendingVerification = PendingVerification(
                destination: destination,
                maskedDestination: result.masked
            )
        } catch is CancellationError {
            state = .idle
        } catch {
            let failure = AuthErrorMapper.failure(for: error, step: .sendCode)
            Log.auth.error("send-code failed: \(String(describing: failure), privacy: .public)")
            state = .failed(failure)
        }
    }
}
