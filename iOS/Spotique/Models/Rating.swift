import Foundation

struct Rating: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let bookingId: String
    let score: RatingScore
    let tags: [String]
    let note: String?
    let createdAt: Date
}

// MARK: - Public Rating Summary

struct PublicRatingSummary: Codable, Sendable, Hashable {
    let userId: String
    let positivePct: Int
    let ratingCount: Int
    let noShowCount: Int
}
