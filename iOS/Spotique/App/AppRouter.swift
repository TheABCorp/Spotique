import SwiftUI

// MARK: - App Tab

enum AppTab: String, Hashable, CaseIterable {
    case explore
    case bookings
    case listings
    case profile
}

// MARK: - App Router

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .explore

    func visibleTabs(for user: User) -> [AppTab] {
        var tabs: [AppTab] = []
        if user.isDriver {
            tabs.append(.explore)
            tabs.append(.bookings)
        }
        if user.isHost {
            tabs.append(.listings)
        }
        tabs.append(.profile)
        return tabs
    }
}
