import Foundation

// MARK: - Auth Destination

enum AuthDestination: Sendable {
    case phone(String)
    case email(String)
}

// MARK: - Auth Responses

struct SendCodeResult: Codable, Sendable {
    let medium: String
    let masked: String
    let expiresIn: Int
}

struct VerifyResult: Codable, Sendable {
    let id: String
    let token: String
    let isNew: Bool
    let user: User?
}

struct CompleteProfileInput: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let address: String
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
