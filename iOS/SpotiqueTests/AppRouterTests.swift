import Testing
import Foundation
@testable import Spotique

@MainActor
struct AppRouterTests {
    @Test func defaultTabIsExplore() {
        let router = AppRouter()
        #expect(router.selectedTab == .explore)
    }

    @Test func driverSeesExploreBookingsProfile() {
        let router = AppRouter()
        let tabs = router.visibleTabs(for: TestHelpers.makeUser(role: .driver))
        #expect(tabs == [.explore, .bookings, .profile])
    }

    @Test func hostSeesListingsProfile() {
        let router = AppRouter()
        let tabs = router.visibleTabs(for: TestHelpers.makeUser(role: .host))
        #expect(tabs == [.listings, .profile])
    }

    @Test func bothRoleSeesAllTabs() {
        let router = AppRouter()
        let tabs = router.visibleTabs(for: TestHelpers.makeUser(role: .both))
        #expect(tabs == [.explore, .bookings, .listings, .profile])
    }
}
