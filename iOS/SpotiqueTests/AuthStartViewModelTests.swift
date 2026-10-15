import Foundation
import Testing
@testable import Spotique

@MainActor
struct AuthStartViewModelTests {
    private let sent = SendCodeResult(medium: "phone", masked: "+1347***1234", expiresIn: 600)

    @Test func startsOnPhoneWithContinueDisabled() {
        let viewModel = AuthStartViewModel(authService: FakeAuthService())

        #expect(viewModel.selectedMedium == .phone)
        #expect(viewModel.state == .idle)
        #expect(!viewModel.canSubmit)
    }

    @Test func validPhoneEnablesContinue() {
        let viewModel = AuthStartViewModel(authService: FakeAuthService())

        viewModel.phoneInput = "(347) 555-1234"

        #expect(viewModel.destination == .phone("+13475551234"))
        #expect(viewModel.canSubmit)
    }

    @Test func destinationFollowsSelectedMedium() {
        let viewModel = AuthStartViewModel(authService: FakeAuthService())
        viewModel.phoneInput = "3475551234"
        viewModel.emailInput = "Jane@Example.com"

        viewModel.selectedMedium = .email

        #expect(viewModel.destination == .email("jane@example.com"))
        #expect(viewModel.phoneInput == "3475551234")
    }

    @Test func sendCodeSucceedsAndQueuesVerification() async {
        let service = FakeAuthService()
        service.sendCodeResult = .success(sent)
        let viewModel = AuthStartViewModel(authService: service)
        viewModel.phoneInput = "347-555-1234"

        await viewModel.sendCode()

        #expect(service.sentDestinations == [.phone("+13475551234")])
        #expect(viewModel.state == .idle)
        #expect(viewModel.pendingVerification == PendingVerification(
            destination: .phone("+13475551234"),
            maskedDestination: "+1347***1234"
        ))
    }

    @Test func sendCodeWithInvalidInputDoesNothing() async {
        let service = FakeAuthService()
        let viewModel = AuthStartViewModel(authService: service)
        viewModel.phoneInput = "555"

        await viewModel.sendCode()

        #expect(service.sentDestinations.isEmpty)
        #expect(viewModel.pendingVerification == nil)
    }

    @Test func rateLimitShowsFailure() async {
        let service = FakeAuthService()
        service.sendCodeResult = .failure(APIError.rateLimited)
        let viewModel = AuthStartViewModel(authService: service)
        viewModel.phoneInput = "3475551234"

        await viewModel.sendCode()

        #expect(viewModel.failure == .rateLimited)
        #expect(viewModel.pendingVerification == nil)
        #expect(viewModel.canSubmit)
    }

    @Test func offlineShowsFailure() async {
        let service = FakeAuthService()
        service.sendCodeResult = .failure(APIError.offline)
        let viewModel = AuthStartViewModel(authService: service)
        viewModel.emailInput = "jane@example.com"
        viewModel.selectedMedium = .email

        await viewModel.sendCode()

        #expect(viewModel.failure == .offline)
    }

    @Test func switchingMediumClearsFailure() async {
        let service = FakeAuthService()
        service.sendCodeResult = .failure(APIError.offline)
        let viewModel = AuthStartViewModel(authService: service)
        viewModel.phoneInput = "3475551234"
        await viewModel.sendCode()

        viewModel.selectedMedium = .email

        #expect(viewModel.failure == nil)
    }

    @Test func cancellationReturnsToIdleWithoutError() async {
        let service = FakeAuthService()
        service.sendCodeResult = .failure(CancellationError())
        let viewModel = AuthStartViewModel(authService: service)
        viewModel.phoneInput = "3475551234"

        await viewModel.sendCode()

        #expect(viewModel.state == .idle)
    }
}
