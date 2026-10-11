import Foundation

/// Mirrors the API `users` table (Api/db/schema.rb).
/// Name and role are nil until the user completes their profile.
nonisolated struct User: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let phone: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let role: UserRole?
    let createdAt: Date
    let updatedAt: Date

    var displayName: String {
        let lastInitial = lastName?.first.map { String($0) } ?? ""
        return [firstName, lastInitial].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    var isHost: Bool {
        role == .host || role == .both
    }

    var isDriver: Bool {
        role == .driver || role == .both
    }
}

nonisolated enum UserRole: String, Codable, Sendable, Hashable, CaseIterable {
    case host
    case driver
    case both
}
