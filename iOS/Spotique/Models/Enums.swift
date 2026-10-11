import Foundation

// MARK: - User Role

enum UserRole: String, Codable, Sendable, Hashable, CaseIterable {
    case host
    case driver
    case both

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = UserRole(rawValue: raw) ?? .driver
    }
}

// MARK: - Spot Type

enum SpotType: String, Codable, Sendable, Hashable, CaseIterable {
    case driveway
    case garage

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SpotType(rawValue: raw) ?? .driveway
    }
}

// MARK: - Booking Status

enum BookingStatus: String, Codable, Sendable, Hashable {
    case pending
    case confirmed
    case declined
    case completed
    case cancelled
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = BookingStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Rating Score

enum RatingScore: Int, Codable, Sendable, Hashable {
    case up = 1
    case down = -1

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Int.self)
        self = RatingScore(rawValue: raw) ?? .up
    }
}

// MARK: - Issue Tags

enum DriverIssueTag: String, Codable, Sendable, Hashable {
    case noShow = "no_show"
    case lateArrival = "late_arrival"
    case didntPay = "didnt_pay"
    case leftMess = "left_mess"
    case rudeBehavior = "rude_behavior"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = DriverIssueTag(rawValue: raw) ?? .rudeBehavior
    }
}

enum HostIssueTag: String, Codable, Sendable, Hashable {
    case spotOccupied = "spot_occupied"
    case misrepresented
    case hostUnreachable = "host_unreachable"
    case accessBlocked = "access_blocked"
    case rudeBehavior = "rude_behavior"
    case falseListing = "false_listing"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = HostIssueTag(rawValue: raw) ?? .rudeBehavior
    }
}

// MARK: - Weekday

enum Weekday: String, Codable, Sendable, Hashable, CaseIterable, CodingKeyRepresentable {
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday
}
