import Foundation

struct Listing: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let hostId: String
    let hostDisplayName: String?
    let hostRatingPositivePct: Int?
    let hostRatingCount: Int?
    let latitude: Double
    let longitude: Double
    let displayAddress: String?
    let spotType: SpotType
    let hourlyRateCents: Int
    let description: String?
    let photos: [URL]
    let availabilitySchedule: [Weekday: DaySchedule]?
    let blockedDates: [String]?
    let paymentMethodText: String?
    let active: Bool
    let createdAt: Date

    /// Full street address — only present when the caller has a confirmed booking.
    let address: String?
}

// MARK: - Day Schedule

struct DaySchedule: Codable, Sendable, Hashable {
    let enabled: Bool
    let start: String?
    let end: String?
}
