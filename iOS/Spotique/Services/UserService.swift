import Foundation

// MARK: - Protocol

protocol UserServicing: Sendable {
    func user(id: UUID) async throws -> User
    func updateUser(id: UUID, _ fields: UserUpdateInput) async throws -> User
    func deleteAccount() async throws
}

// MARK: - Update Input

/// Fields accepted by `PATCH /users/:id`. Nil fields are omitted from the
/// request body, so only the fields being changed are sent.
nonisolated struct UserUpdateInput: Encodable, Sendable, Equatable {
    var firstName: String?
    var lastName: String?
    var role: UserRole?
}

// MARK: - Live Implementation

struct LiveUserService: UserServicing {
    let apiClient: APIClient

    func user(id: UUID) async throws -> User {
        let endpoint = Endpoint(method: .get, path: path(for: id))
        return try await apiClient.send(endpoint)
    }

    func updateUser(id: UUID, _ fields: UserUpdateInput) async throws -> User {
        let endpoint = Endpoint(method: .patch, path: path(for: id), body: ["user": fields])
        return try await apiClient.send(endpoint)
    }

    // TODO: Account deletion is required before App Store submission
    // (PRD §4.8, App Review Guideline 5.1.1(v)). The API has no DELETE
    // endpoint yet, so this throws `.notFound`.
    func deleteAccount() async throws {
        throw APIError.notFound
    }

    private func path(for id: UUID) -> String {
        "/users/\(id.uuidString.lowercased())"
    }
}
