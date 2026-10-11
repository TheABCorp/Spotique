import Foundation

// MARK: - Protocol

protocol UserServicing: Sendable {
    func currentUser() async throws -> User
    func update(_ fields: UserUpdateInput) async throws -> User
    func deleteAccount() async throws
}

// MARK: - Update Input

struct UserUpdateInput: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
    var address: String?
    var role: UserRole?
    var paymentMethodText: String?
}

// MARK: - Live Implementation

// TODO: Implement once the API has a users resource endpoint (read, update,
// delete for the signed-in user). The API doesn't expose one yet, so these
// throw `.notFound`, which matches what the server currently returns.
struct LiveUserService: UserServicing {
    let apiClient: APIClient

    func currentUser() async throws -> User {
        throw APIError.notFound
    }

    func update(_ fields: UserUpdateInput) async throws -> User {
        throw APIError.notFound
    }

    func deleteAccount() async throws {
        throw APIError.notFound
    }
}
