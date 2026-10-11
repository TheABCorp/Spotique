import Foundation
import OSLog

/// Second auth step: enter the 6-digit code. On success the session moves to
/// signed in (complete profile) or needs-profile, and `RootView` switches screens.
@Observable
@MainActor
final class CodeVerificationViewModel {
    enum State: Equatable {
        case idle
        case verifying
        case resending
        case failed(AuthFailure)
    }

    static let codeLength = 6
    /// Client-side wait before resend (PRD §4.1); the server allows 3 codes/hour.
    static let resendDelay: TimeInterval = 60

    /// Digits only, at most six; anything else typed or pasted is dropped.
    var code = "" {
        didSet {
            let digits = String(code.filter { $0.isASCII && $0.isNumber }.prefix(Self.codeLength))
            if digits != code { code = digits }
        }
    }
    private(set) var state: State = .idle
    private(set) var maskedDestination: String
    private(set) var resendAvailableAt: Date
    /// Set when the server refuses more codes this hour; resend stays off.
    private(set) var isResendBlocked = false

    private let destination: AuthDestination
    private let authService: any AuthServicing
    private let sessionStore: SessionStore
    private let now: () -> Date

    init(
        pending: PendingVerification,
        authService: any AuthServicing,
        sessionStore: SessionStore,
        now: @escaping () -> Date = Date.init
    ) {
        destination = pending.destination
        maskedDestination = pending.maskedDestination
        self.authService = authService
        self.sessionStore = sessionStore
        self.now = now
        resendAvailableAt = now().addingTimeInterval(Self.resendDelay)
    }

    var failure: AuthFailure? {
        if case .failed(let failure) = state { failure } else { nil }
    }

    var isBusy: Bool {
        state == .verifying || state == .resending
    }

    var canVerify: Bool {
        code.count == Self.codeLength && !isBusy
    }

    var usesPhone: Bool {
        destination.medium == .phone
    }

    func secondsUntilResend(at date: Date) -> Int {
        max(0, Int(resendAvailableAt.timeIntervalSince(date).rounded(.up)))
    }

    func canResend(at date: Date) -> Bool {
        !isResendBlocked && !isBusy && secondsUntilResend(at: date) == 0
    }

    // MARK: - Actions

    func verify() async {
        guard canVerify else { return }
        state = .verifying

        do {
            let result = try await authService.verify(destination, code: code)
            state = .idle
            if let user = result.user, !result.isNew, user.isProfileComplete {
                sessionStore.signIn(token: result.token, user: user)
            } else {
                sessionStore.signInNeedingProfile(token: result.token, userID: result.id)
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            handleVerifyFailure(AuthErrorMapper.failure(for: error, step: .verify))
        }
    }

    func resend() async {
        guard canResend(at: now()) else { return }
        state = .resending

        do {
            let result = try await authService.sendCode(destination)
            maskedDestination = result.masked
            code = ""
            resendAvailableAt = now().addingTimeInterval(Self.resendDelay)
            state = .idle
        } catch is CancellationError {
            state = .idle
        } catch {
            let failure = AuthErrorMapper.failure(for: error, step: .sendCode)
            Log.auth.error("resend failed: \(String(describing: failure), privacy: .public)")
            if failure == .rateLimited { isResendBlocked = true }
            state = .failed(failure)
        }
    }

    private func handleVerifyFailure(_ failure: AuthFailure) {
        Log.auth.error("verify failed: \(String(describing: failure), privacy: .public)")
        code = ""
        // An expired or locked code can't be retried; let the user resend now.
        if failure == .codeExpired || failure == .tooManyAttempts {
            resendAvailableAt = now()
        }
        state = .failed(failure)
    }
}
