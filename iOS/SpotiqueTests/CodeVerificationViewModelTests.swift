import Foundation
import Testing
@testable import Spotique

@MainActor
struct CodeVerificationViewModelTests {
    private let pending = PendingVerification(destination: .phone("+13475551234"), maskedDestination: "+1347***1234")
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private final class Clock {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func make(
        service: FakeAuthService = FakeAuthService(),
        tokenStore: FakeTokenStore = FakeTokenStore(),
        clock: Clock? = nil
    ) -> (CodeVerificationViewModel, SessionStore) {
        let clock = clock ?? Clock(start)
        let session = SessionStore(tokenStore: tokenStore, userService: FakeUserService())
        let viewModel = CodeVerificationViewModel(
            pending: pending, authService: service, sessionStore: session, now: { clock.now }
        )
        return (viewModel, session)
    }

    private func completeUser() -> User {
        let address = Address(
            id: UUID(), label: .home, street: "34-15 74th Street", city: "Jackson Heights",
            state: "NY", zip: "11372", latitude: nil, longitude: nil
        )
        return User(
            id: TestHelpers.sampleUserID, phone: "+13475551234", email: nil, firstName: "Jane",
            lastName: "Doe", role: .driver, addresses: [address], createdAt: start, updatedAt: start
        )
    }

    // MARK: - Code input

    @Test func codeKeepsOnlySixDigits() {
        let (viewModel, _) = make()

        viewModel.code = "12a3-45 678"

        #expect(viewModel.code == "123456")
        #expect(viewModel.canVerify)
    }

    @Test func cannotVerifyIncompleteCode() async {
        let service = FakeAuthService()
        let (viewModel, _) = make(service: service)
        viewModel.code = "123"

        await viewModel.verify()

        #expect(service.verifiedCodes.isEmpty)
    }

    // MARK: - Verify outcomes

    @Test func existingCompleteUserSignsIn() async {
        let service = FakeAuthService()
        let user = completeUser()
        service.verifyResult = .success(VerifyResult(id: user.id, token: "jwt", isNew: false, user: user))
        let tokenStore = FakeTokenStore()
        let (viewModel, session) = make(service: service, tokenStore: tokenStore)
        viewModel.code = "123456"

        await viewModel.verify()

        #expect(service.verifiedCodes == ["123456"])
        #expect(session.state == .signedIn(user))
        #expect(tokenStore.token() == "jwt")
        #expect(tokenStore.userID() == user.id)
    }

    @Test func newUserNeedsProfile() async {
        let service = FakeAuthService()
        service.verifyResult = .success(VerifyResult(id: TestHelpers.sampleUserID, token: "jwt", isNew: true, user: nil))
        let tokenStore = FakeTokenStore()
        let (viewModel, session) = make(service: service, tokenStore: tokenStore)
        viewModel.code = "123456"

        await viewModel.verify()

        #expect(session.state == .needsProfile)
        #expect(tokenStore.userID() == TestHelpers.sampleUserID)
    }

    @Test func existingIncompleteUserNeedsProfile() async {
        let service = FakeAuthService()
        let incomplete = TestHelpers.makeUser(firstName: nil, role: nil)
        service.verifyResult = .success(VerifyResult(id: incomplete.id, token: "jwt", isNew: false, user: incomplete))
        let (viewModel, session) = make(service: service)
        viewModel.code = "123456"

        await viewModel.verify()

        #expect(session.state == .needsProfile)
    }

    @Test func invalidCodeClearsInputAndKeepsCountdown() async {
        let service = FakeAuthService()
        service.verifyResult = .failure(APIError.unauthorized(message: "Invalid code. Please try again."))
        let (viewModel, session) = make(service: service)
        viewModel.code = "000000"

        await viewModel.verify()

        #expect(viewModel.failure == .invalidCode)
        #expect(viewModel.code.isEmpty)
        #expect(session.state == .launching)
        #expect(!viewModel.canResend(at: start))
    }

    @Test func expiredCodeEnablesResendImmediately() async {
        let service = FakeAuthService()
        service.verifyResult = .failure(APIError.unauthorized(message: "No active verification code found. Request a new one."))
        let (viewModel, _) = make(service: service)
        viewModel.code = "123456"

        await viewModel.verify()

        #expect(viewModel.failure == .codeExpired)
        #expect(viewModel.canResend(at: start))
    }

    @Test func tooManyAttemptsEnablesResend() async {
        let service = FakeAuthService()
        service.verifyResult = .failure(APIError.rateLimited)
        let (viewModel, _) = make(service: service)
        viewModel.code = "123456"

        await viewModel.verify()

        #expect(viewModel.failure == .tooManyAttempts)
        #expect(viewModel.code.isEmpty)
        #expect(viewModel.canResend(at: start))
    }

    // MARK: - Resend

    @Test func resendCountsDownFromSixty() {
        let (viewModel, _) = make()

        #expect(viewModel.secondsUntilResend(at: start) == 60)
        #expect(viewModel.secondsUntilResend(at: start.addingTimeInterval(15.2)) == 45)
        #expect(!viewModel.canResend(at: start.addingTimeInterval(59)))
        #expect(viewModel.canResend(at: start.addingTimeInterval(60)))
    }

    @Test func resendSendsNewCodeAndRestartsCountdown() async {
        let service = FakeAuthService()
        service.sendCodeResult = .success(SendCodeResult(medium: "phone", masked: "+1347***9999", expiresIn: 600))
        let clock = Clock(start)
        let (viewModel, _) = make(service: service, clock: clock)
        clock.now = start.addingTimeInterval(61)
        viewModel.code = "12"

        await viewModel.resend()

        #expect(service.sentDestinations == [.phone("+13475551234")])
        #expect(viewModel.maskedDestination == "+1347***9999")
        #expect(viewModel.code.isEmpty)
        #expect(viewModel.secondsUntilResend(at: clock.now) == 60)
    }

    @Test func resendBeforeCountdownDoesNothing() async {
        let service = FakeAuthService()
        let (viewModel, _) = make(service: service)

        await viewModel.resend()

        #expect(service.sentDestinations.isEmpty)
    }

    @Test func rateLimitedResendBlocksResend() async {
        let service = FakeAuthService()
        service.sendCodeResult = .failure(APIError.rateLimited)
        let clock = Clock(start)
        let (viewModel, _) = make(service: service, clock: clock)
        clock.now = start.addingTimeInterval(61)

        await viewModel.resend()

        #expect(viewModel.failure == .rateLimited)
        #expect(viewModel.isResendBlocked)
        #expect(!viewModel.canResend(at: clock.now.addingTimeInterval(600)))
    }
}
