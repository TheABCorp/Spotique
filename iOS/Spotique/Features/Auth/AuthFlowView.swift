import SwiftUI

/// Root of the signed-out experience. Every step after verification hands off
/// to `SessionStore`, and `RootView` switches screens on its state; this flow
/// never pushes into the main app itself.
struct AuthFlowView: View {
    @State private var startViewModel: AuthStartViewModel

    init(authService: any AuthServicing) {
        _startViewModel = State(initialValue: AuthStartViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            AuthStartView(viewModel: startViewModel)
        }
    }
}
