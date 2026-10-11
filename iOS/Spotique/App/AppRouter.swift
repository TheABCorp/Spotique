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

    /// A host-only user has no Explore tab, so the default selection would
    /// point at a hidden tab. Fall back to their first visible tab.
    func selectFirstTabIfHidden(for user: User) {
        let tabs = visibleTabs(for: user)
        if !tabs.contains(selectedTab), let first = tabs.first {
            selectedTab = first
        }
    }
}
