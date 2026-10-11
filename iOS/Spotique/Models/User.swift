import Foundation

struct User: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let phone: String?
    let email: String?
    let firstName: String
    let lastName: String
    let address: String?
    let role: UserRole
    let ratingPositivePct: Int?
    let ratingCount: Int?
    let noShowCount: Int?
    let createdAt: Date
    let paymentMethodText: String?

    var displayName: String {
        let lastInitial = lastName.first.map { String($0) } ?? ""
        return "\(firstName) \(lastInitial)"
    }

    var isHost: Bool {
        role == .host || role == .both
    }

    var isDriver: Bool {
        role == .driver || role == .both
    }
}
