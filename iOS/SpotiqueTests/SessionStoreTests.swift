import Foundation
import Testing
@testable import Spotique

@MainActor
struct SessionStoreTests {
    @Test func restoreWithoutTokenSignsOut() async {
        let store = SessionStore(
            tokenStore: InMemoryTokenStore(),
            userService: StubUserService(result: .success(Fixtures.user()))
        )

        await store.restore()

        #expect(store.state == .signedOut)
    }

    @Test func restoreWithTokenButNoUserIDSignsOutAndClearsToken() async {
        let tokenStore = InMemoryTokenStore(token: "token")
        let store = SessionStore(
            tokenStore: tokenStore,
            userService: StubUserService(result: .success(Fixtures.user()))
        )

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(tokenStore.token() == nil)
    }

    @Test func restoreFetchesUserAndSignsIn() async {
        let user = Fixtures.user()
        let store = SessionStore(
            tokenStore: InMemoryTokenStore(token: "token", userID: user.id),
            userService: StubUserService(result: .success(user))
        )

        await store.restore()

        #expect(store.state == .signedIn(user))
        #expect(store.currentUser == user)
    }

    @Test func restoreWithIncompleteProfileNeedsProfile() async {
        let store = SessionStore(
            tokenStore: InMemoryTokenStore(token: "token", userID: Fixtures.userID),
            userService: StubUserService(result: .failure(.profileIncomplete))
        )

        await store.restore()

        #expect(store.state == .needsProfile)
    }

    @Test func restoreWhenUnauthorizedSignsOutAndClearsToken() async {
        let tokenStore = InMemoryTokenStore(token: "expired", userID: Fixtures.userID)
        let store = SessionStore(
            tokenStore: tokenStore,
            userService: StubUserService(result: .failure(.unauthorized(message: nil)))
        )

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(tokenStore.token() == nil)
        #expect(tokenStore.userID() == nil)
    }

    @Test func restoreWhenOfflineSignsOutButKeepsToken() async {
        let tokenStore = InMemoryTokenStore(token: "token", userID: Fixtures.userID)
        let store = SessionStore(
            tokenStore: tokenStore,
            userService: StubUserService(result: .failure(.offline))
        )

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(tokenStore.token() == "token")
    }

    @Test func signInSavesTokenAndUserID() {
        let tokenStore = InMemoryTokenStore()
        let user = Fixtures.user()
        let store = SessionStore(
            tokenStore: tokenStore,
            userService: StubUserService(result: .success(user))
        )

        store.signIn(token: "token", user: user)

        #expect(tokenStore.token() == "token")
        #expect(tokenStore.userID() == user.id)
        #expect(store.state == .signedIn(user))
    }

    @Test func signInNeedingProfileSavesTokenAndUserID() {
        let tokenStore = InMemoryTokenStore()
        let store = SessionStore(
            tokenStore: tokenStore,
            userService: StubUserService(result: .success(Fixtures.user()))
        )

        store.signInNeedingProfile(token: "token", userID: Fixtures.userID)

        #expect(tokenStore.userID() == Fixtures.userID)
        #expect(store.state == .needsProfile)
    }
}
