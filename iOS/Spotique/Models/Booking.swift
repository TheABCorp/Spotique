import Foundation

struct Booking: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let listingId: String
    let driverId: String
    let hostId: String
    let status: BookingStatus
    let startTime: Date
    let endTime: Date
    let totalCents: Int
    let noShow: Bool
    let declineReason: String?
    let createdAt: Date

    // Hidden fields — only populated for confirmed bookings.
    let address: String?
    let hostPhone: String?
    let driverPhone: String?
    let paymentMethodText: String?

    // Optional summary fields for display (populated by future API additions).
    let listing: ListingSummary?
    let host: ParticipantSummary?
    let driver: ParticipantSummary?
}

// MARK: - Summary Types

struct ListingSummary: Codable, Sendable, Hashable {
    let id: String
    let displayAddress: String?
    let spotType: SpotType?
}

struct ParticipantSummary: Codable, Sendable, Hashable {
    let id: String
    let displayName: String?
}
