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

struct LiveUserService: UserServicing {
    let apiClient: APIClient

    func currentUser() async throws -> User {
        let endpoint = Endpoint(method: .get, path: "/users/me")
        return try await apiClient.send(endpoint)
    }

    func update(_ fields: UserUpdateInput) async throws -> User {
        let endpoint = Endpoint(
            method: .patch,
            path: "/users/me",
            body: ["user": fields]
        )
        return try await apiClient.send(endpoint)
    }

    func deleteAccount() async throws {
        let endpoint = Endpoint(method: .delete, path: "/users/me")
        try await apiClient.sendEmpty(endpoint)
    }
}
