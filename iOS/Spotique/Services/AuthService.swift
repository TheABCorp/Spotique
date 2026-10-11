import Foundation

// MARK: - Auth Destination

nonisolated enum AuthDestination: Sendable {
    case phone(String)
    case email(String)
}

// MARK: - Auth Responses

nonisolated struct SendCodeResult: Codable, Sendable {
    let medium: String
    let masked: String
    let expiresIn: Int
}

nonisolated struct VerifyResult: Codable, Sendable {
    let id: UUID
    let token: String
    let isNew: Bool
    let user: User?
}

nonisolated struct CompleteProfileInput: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let address: AddressInput
    let role: UserRole
}

// MARK: - Protocol

protocol AuthServicing: Sendable {
    func sendCode(_ destination: AuthDestination) async throws -> SendCodeResult
    func verify(_ destination: AuthDestination, code: String) async throws -> VerifyResult
    func completeProfile(_ input: CompleteProfileInput) async throws -> User
}

// MARK: - Live Implementation

struct LiveAuthService: AuthServicing {
    let apiClient: APIClient

    func sendCode(_ destination: AuthDestination) async throws -> SendCodeResult {
        var body: [String: String] = [:]
        switch destination {
        case .phone(let phone): body["phone"] = phone
        case .email(let email): body["email"] = email
        }

        let endpoint = Endpoint(
            method: .post,
            path: "/auth/send-code",
            body: body,
            requiresAuth: false,
            handlesUnauthorized: false
        )
        return try await apiClient.send(endpoint)
    }

    func verify(_ destination: AuthDestination, code: String) async throws -> VerifyResult {
        var body: [String: String] = ["code": code]
        switch destination {
        case .phone(let phone): body["phone"] = phone
        case .email(let email): body["email"] = email
        }

        let endpoint = Endpoint(
            method: .post,
            path: "/auth/verify",
            body: body,
            requiresAuth: false,
            handlesUnauthorized: false
        )
        return try await apiClient.send(endpoint)
    }

    func completeProfile(_ input: CompleteProfileInput) async throws -> User {
        let endpoint = Endpoint(
            method: .post,
            path: "/auth/complete-profile",
            body: ["user": input]
        )
        return try await apiClient.send(endpoint)
    }
}
