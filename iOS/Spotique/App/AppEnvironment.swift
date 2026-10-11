import Foundation

@Observable
@MainActor
final class AppEnvironment {
    let apiClient: APIClient
    let authService: any AuthServicing
    let sessionStore: SessionStore
    let userService: any UserServicing

    init(
        apiClient: APIClient,
        authService: any AuthServicing,
        sessionStore: SessionStore,
        userService: any UserServicing
    ) {
        self.apiClient = apiClient
        self.authService = authService
        self.sessionStore = sessionStore
        self.userService = userService
    }

    static func live(configuration: APIConfiguration = .current) -> AppEnvironment {
        let tokenStore = KeychainTokenStore()
        let userService = LiveUserService(apiClient: APIClient(
            configuration: configuration,
            tokenProvider: tokenStore,
            onUnauthorized: {}
        ))
        let sessionStore = SessionStore(tokenStore: tokenStore, userService: userService)

        let apiClient = APIClient(
            configuration: configuration,
            tokenProvider: sessionStore,
            onUnauthorized: { [weak sessionStore] in
                Task { @MainActor in
                    await sessionStore?.signOut()
                }
            }
        )

        let authService = LiveAuthService(apiClient: apiClient)
        let liveUserService = LiveUserService(apiClient: apiClient)

        return AppEnvironment(
            apiClient: apiClient,
            authService: authService,
            sessionStore: sessionStore,
            userService: liveUserService
        )
    }
}
