import Foundation
import Testing
@testable import Spotique

@MainActor
struct ProfileCompletionViewModelTests {
    private func make(
        service: FakeAuthService = FakeAuthService(),
        tokenStore: FakeTokenStore = FakeTokenStore(token: "jwt", userID: TestHelpers.sampleUserID)
    ) -> (ProfileCompletionViewModel, SessionStore) {
        let session = SessionStore(tokenStore: tokenStore, userService: FakeUserService())
        session.signInNeedingProfile(token: "jwt", userID: TestHelpers.sampleUserID)
        return (ProfileCompletionViewModel(authService: service, sessionStore: session), session)
    }

    private func fill(_ viewModel: ProfileCompletionViewModel) {
        viewModel.firstName = "  Jane "
        viewModel.lastName = "Doe"
        viewModel.street = "34-15 74th Street"
        viewModel.role = .host
    }

    // MARK: - Validation

    @Test func startsWithJacksonHeightsPrefilledAndInvalid() {
        let (viewModel, _) = make()

        #expect(viewModel.city == "Jackson Heights")
        #expect(viewModel.stateCode == "NY")
        #expect(viewModel.zip == "11372")
        #expect(viewModel.role == nil)
        #expect(!viewModel.canSubmit)
    }

    @Test func requiresEveryFieldAndARole() {
        let (viewModel, _) = make()
        fill(viewModel)
        #expect(viewModel.canSubmit)

        viewModel.role = nil
        #expect(!viewModel.canSubmit)

        viewModel.role = .driver
        viewModel.street = "   "
        #expect(!viewModel.canSubmit)
    }

    @Test func nameLongerThanFiftyCharactersIsAnError() {
        let (viewModel, _) = make()
        fill(viewModel)

        viewModel.lastName = String(repeating: "a", count: 50)
        #expect(viewModel.error(for: .lastName) == nil)
        #expect(viewModel.canSubmit)

        viewModel.lastName = String(repeating: "a", count: 51)
        #expect(viewModel.error(for: .lastName) != nil)
        #expect(!viewModel.canSubmit)
    }

    @Test func zipMustBeFiveDigits() {
        let (viewModel, _) = make()
        fill(viewModel)

        viewModel.zip = "1137"
        #expect(viewModel.error(for: .zip) != nil)
        #expect(!viewModel.canSubmit)
    }

    // MARK: - Submit

    @Test func submitSendsTrimmedProfileAndSignsIn() async throws {
        let service = FakeAuthService()
        let user = TestHelpers.makeUser(role: .host)
        service.completeProfileResult = .success(user)
        let (viewModel, session) = make(service: service)
        fill(viewModel)

        await viewModel.submit()

        let sent = try #require(service.completedProfiles.first)
        #expect(sent.firstName == "Jane")
        #expect(sent.role == .host)
        #expect(sent.address == AddressInput(
            label: .home, street: "34-15 74th Street", city: "Jackson Heights", state: "NY", zip: "11372"
        ))
        #expect(session.state == .signedIn(user))
    }

    @Test func serverFieldErrorsAreShownOnFields() async {
        let service = FakeAuthService()
        service.completeProfileResult = .failure(APIError.validation(
            message: "Validation failed",
            fields: ["first_name": ["can't be blank"], "address": ["can't be blank"]]
        ))
        let (viewModel, session) = make(service: service)
        fill(viewModel)

        await viewModel.submit()

        #expect(viewModel.error(for: .firstName) != nil)
        #expect(viewModel.error(for: .street) != nil)
        #expect(viewModel.error(for: .lastName) == nil)
        #expect(session.state == .needsProfile)

        viewModel.clearServerError(for: .firstName)
        #expect(viewModel.error(for: .firstName) == nil)
    }

    @Test func alreadyCompletedSignsOut() async {
        let service = FakeAuthService()
        service.completeProfileResult = .failure(APIError.conflict(code: nil, message: "Profile already completed"))
        let tokenStore = FakeTokenStore(token: "jwt", userID: TestHelpers.sampleUserID)
        let (viewModel, session) = make(service: service, tokenStore: tokenStore)
        fill(viewModel)

        await viewModel.submit()

        #expect(viewModel.failure == .profileAlreadyCompleted)
        #expect(session.state == .signedOut)
        #expect(tokenStore.token() == nil)
    }

    @Test func offlineKeepsFormForRetry() async {
        let service = FakeAuthService()
        service.completeProfileResult = .failure(APIError.offline)
        let (viewModel, session) = make(service: service)
        fill(viewModel)

        await viewModel.submit()

        #expect(viewModel.failure == .offline)
        #expect(viewModel.canSubmit)
        #expect(viewModel.lastName == "Doe")
        #expect(session.state == .needsProfile)
    }

    @Test func submitWhenInvalidSendsNothing() async {
        let service = FakeAuthService()
        let (viewModel, _) = make(service: service)

        await viewModel.submit()

        #expect(service.completedProfiles.isEmpty)
    }

    @Test func signOutClearsSession() async {
        let tokenStore = FakeTokenStore(token: "jwt", userID: TestHelpers.sampleUserID)
        let (viewModel, session) = make(tokenStore: tokenStore)

        await viewModel.signOut()

        #expect(session.state == .signedOut)
        #expect(tokenStore.token() == nil)
    }
}
