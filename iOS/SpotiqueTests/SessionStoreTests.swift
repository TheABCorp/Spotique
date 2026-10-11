import Foundation
import Testing
@testable import Spotique

@MainActor
struct SessionStoreTests {
    @Test func startsInLaunchingState() {
        let store = makeSessionStore()
        #expect(store.state == .launching)
    }

    // MARK: - Restore

    @Test func restoreWithoutTokenSignsOut() async {
        let store = makeSessionStore()

        await store.restore()

        #expect(store.state == .signedOut)
    }

    @Test func restoreWithTokenButNoUserIDSignsOutAndClearsToken() async {
        let tokenStore = FakeTokenStore(token: "token")
        let store = makeSessionStore(tokenStore: tokenStore)

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(tokenStore.token() == nil)
    }

    @Test func restoreFetchesUserAndSignsIn() async {
        let user = TestHelpers.sampleUser
        let store = makeSessionStore(
            tokenStore: FakeTokenStore(token: "token", userID: user.id),
            userService: FakeUserService(userResult: .success(user))
        )

        await store.restore()

        #expect(store.state == .signedIn(user))
        #expect(store.currentUser == user)
    }

    @Test func restoreWithIncompleteProfileNeedsProfile() async {
        let store = makeSessionStore(
            tokenStore: FakeTokenStore(token: "token", userID: TestHelpers.sampleUserID),
            userService: FakeUserService(userResult: .failure(APIError.profileIncomplete))
        )

        await store.restore()

        #expect(store.state == .needsProfile)
    }

    @Test func restoreWhenUnauthorizedSignsOutAndClearsToken() async {
        let tokenStore = FakeTokenStore(token: "expired", userID: TestHelpers.sampleUserID)
        let store = makeSessionStore(
            tokenStore: tokenStore,
            userService: FakeUserService(userResult: .failure(APIError.unauthorized(message: nil)))
        )

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(tokenStore.token() == nil)
        #expect(tokenStore.userID() == nil)
    }

    @Test func restoreWhenOfflineSignsOutButKeepsToken() async {
        let tokenStore = FakeTokenStore(token: "token", userID: TestHelpers.sampleUserID)
        let store = makeSessionStore(
            tokenStore: tokenStore,
            userService: FakeUserService(userResult: .failure(APIError.offline))
        )

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(tokenStore.token() == "token")
    }

    // MARK: - Sign In

    @Test func signInSavesTokenAndUserID() {
        let tokenStore = FakeTokenStore()
        let user = TestHelpers.sampleUser
        let store = makeSessionStore(tokenStore: tokenStore)

        store.signIn(token: "token", user: user)

        #expect(tokenStore.token() == "token")
        #expect(tokenStore.userID() == user.id)
        #expect(store.currentUser == user)
        #expect(store.state == .signedIn(user))
    }

    @Test func signInNeedingProfileSavesTokenAndUserID() {
        let tokenStore = FakeTokenStore()
        let store = makeSessionStore(tokenStore: tokenStore)

        store.signInNeedingProfile(token: "token", userID: TestHelpers.sampleUserID)

        #expect(tokenStore.token() == "token")
        #expect(tokenStore.userID() == TestHelpers.sampleUserID)
        #expect(store.state == .needsProfile)
    }

    @Test func profileCompletedTransitionsToSignedIn() {
        let store = makeSessionStore()
        store.signInNeedingProfile(token: "token", userID: TestHelpers.sampleUserID)

        store.profileCompleted(user: TestHelpers.sampleUser)

        #expect(store.state == .signedIn(TestHelpers.sampleUser))
    }

    // MARK: - Sign Out

    @Test func signOutClearsTokenAndUser() async {
        let tokenStore = FakeTokenStore()
        let store = makeSessionStore(tokenStore: tokenStore)
        store.signIn(token: "token", user: TestHelpers.sampleUser)

        await store.signOut()

        #expect(tokenStore.token() == nil)
        #expect(tokenStore.userID() == nil)
        #expect(store.currentUser == nil)
        #expect(store.state == .signedOut)
    }

    @Test func signOutCallsCleanupHandlers() async {
        let store = makeSessionStore()
        var cleanupCalled = false
        store.register { cleanupCalled = true }
        store.signIn(token: "token", user: TestHelpers.sampleUser)

        await store.signOut()

        #expect(cleanupCalled)
    }

    // MARK: - Helpers

    private func makeSessionStore(
        tokenStore: FakeTokenStore = FakeTokenStore(),
        userService: FakeUserService = FakeUserService()
    ) -> SessionStore {
        SessionStore(tokenStore: tokenStore, userService: userService)
    }
}
