import Foundation

// MARK: - Session State

enum SessionState: Equatable {
    case launching
    case signedOut
    case needsProfile
    case signedIn(User)

    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.launching, .launching): return true
        case (.signedOut, .signedOut): return true
        case (.needsProfile, .needsProfile): return true
        case let (.signedIn(l), .signedIn(r)): return l == r
        default: return false
        }
    }
}

// MARK: - Session Store

@Observable
@MainActor
final class SessionStore {
    private(set) var state: SessionState = .launching
    private(set) var currentUser: User?

    private let tokenStore: any TokenStoring
    private let userService: any UserServicing
    private var cleanupHandlers: [@MainActor () async -> Void] = []

    init(tokenStore: any TokenStoring, userService: any UserServicing) {
        self.tokenStore = tokenStore
        self.userService = userService
    }

    // MARK: - Session Lifecycle

    func restore() async {
        guard tokenStore.token() != nil else {
            state = .signedOut
            return
        }

        do {
            let user = try await userService.currentUser()
            currentUser = user
            state = .signedIn(user)
        } catch let error as APIError {
            switch error {
            case .profileIncomplete:
                state = .needsProfile
            case .unauthorized:
                await signOut()
            default:
                state = .signedOut
            }
        } catch {
            state = .signedOut
        }
    }

    func signIn(token: String, user: User) {
        try? tokenStore.save(token)
        currentUser = user
        state = .signedIn(user)
    }

    func signInNeedingProfile(token: String) {
        try? tokenStore.save(token)
        state = .needsProfile
    }

    func profileCompleted(user: User) {
        currentUser = user
        state = .signedIn(user)
    }

    func update(user: User) {
        currentUser = user
        if case .signedIn = state {
            state = .signedIn(user)
        }
    }

    func signOut() async {
        for cleanup in cleanupHandlers {
            await cleanup()
        }
        tokenStore.clear()
        currentUser = nil
        state = .signedOut
    }

    // MARK: - Cleanup Registry

    func register(cleanup: @escaping @MainActor () async -> Void) {
        cleanupHandlers.append(cleanup)
    }
}

// MARK: - TokenProviding Conformance

extension SessionStore: TokenProviding {
    nonisolated func token() -> String? {
        tokenStore.token()
    }
}
