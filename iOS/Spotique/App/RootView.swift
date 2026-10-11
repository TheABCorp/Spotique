import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var body: some View {
        switch environment.sessionStore.state {
        case .launching:
            LaunchView()
        case .signedOut:
            AuthFlowPlaceholder()
        case .needsProfile:
            ProfileCompletionPlaceholder()
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

// MARK: - Placeholders (replaced by feature plans)

private struct AuthFlowPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandNavy)
            Text("Spotique")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.brandNavy)
            Text("Find parking")
                .font(.subheadline)
                .foregroundStyle(Color.onSurface.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surface.ignoresSafeArea())
    }
}

private struct ProfileCompletionPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandNavy)
            Text("Complete Your Profile")
                .font(.title2.bold())
                .foregroundStyle(Color.brandNavy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surface.ignoresSafeArea())
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

#Preview {
    RootView()
}

