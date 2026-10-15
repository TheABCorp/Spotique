import SwiftUI

/// Root of the signed-out experience. Every step after verification hands off
/// to `SessionStore`, and `RootView` switches screens on its state; this flow
/// never pushes into the main app itself.
struct AuthFlowView: View {
    @State private var startViewModel: AuthStartViewModel
    private let authService: any AuthServicing
    private let sessionStore: SessionStore

    init(authService: any AuthServicing, sessionStore: SessionStore) {
        self.authService = authService
        self.sessionStore = sessionStore
        _startViewModel = State(initialValue: AuthStartViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            AuthStartView(viewModel: startViewModel)
                .navigationDestination(item: $startViewModel.pendingVerification) { pending in
                    CodeVerificationView(viewModel: CodeVerificationViewModel(
                        pending: pending,
                        authService: authService,
                        sessionStore: sessionStore
                    ))
                }
        }
    }
}
