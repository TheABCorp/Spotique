import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        switch environment.sessionStore.state {
        case .launching:
            LaunchView()
        case .signedOut:
            AuthFlowView(authService: environment.authService, sessionStore: environment.sessionStore)
        case .needsProfile:
            ProfileCompletionView(viewModel: ProfileCompletionViewModel(
                authService: environment.authService,
                sessionStore: environment.sessionStore
            ))
        case .signedIn(let user):
            MainTabView(user: user)
        }
    }
}

// MARK: - Launch View

private struct LaunchView: View {
    var body: some View {
        ZStack {
            Color.brandNavy.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Spotique")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.brandIvory)
                ProgressView()
                    .tint(.brandGold)
            }
        }
    }
}

// MARK: - Main Tab View

private struct MainTabView: View {
    let user: User
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ForEach(router.visibleTabs(for: user), id: \.self) { tab in
                TabPlaceholder(tab: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .onAppear { router.selectFirstTabIfHidden(for: user) }
    }
}

// MARK: - Tab Helpers

extension AppTab {
    var title: String {
        switch self {
        case .explore: String(localized: "Explore")
        case .bookings: String(localized: "Bookings")
        case .listings: String(localized: "Listings")
        case .profile: String(localized: "Profile")
        }
    }

    var systemImage: String {
        switch self {
        case .explore: "map"
        case .bookings: "calendar"
        case .listings: "list.bullet"
        case .profile: "person"
        }
    }
}

private struct TabPlaceholder: View {
    let tab: AppTab

    var body: some View {
        NavigationStack {
            Text(tab.title)
                .navigationTitle(tab.title)
        }
    }
}

