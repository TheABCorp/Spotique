import Foundation
import OSLog
import Security

// MARK: - Protocol

/// Persists the session credentials: the bearer token and the signed-in
/// user's ID, which is needed to fetch `GET /users/:id` on relaunch.
nonisolated protocol TokenStoring: Sendable {
    func token() -> String?
    func userID() -> UUID?
    func save(token: String, userID: UUID) throws
    func clear()
}

// MARK: - Keychain Implementation

nonisolated struct KeychainTokenStore: TokenStoring, Sendable {
    private let service: String
    private let tokenAccount = "auth-token"
    private let userIDAccount = "user-id"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.actionman.Spotique") {
        self.service = service
    }

    func token() -> String? {
        read(account: tokenAccount)
    }

    func userID() -> UUID? {
        read(account: userIDAccount).flatMap(UUID.init(uuidString:))
    }

    func save(token: String, userID: UUID) throws {
        clear()
        do {
            try write(token, account: tokenAccount)
            try write(userID.uuidString, account: userIDAccount)
        } catch {
            clear()
            throw error
        }
    }

    func clear() {
        delete(account: tokenAccount)
        delete(account: userIDAccount)
    }

    // MARK: - Keychain Access

    private func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Log.auth.error("Keychain save failed: \(status)")
            throw KeychainError.saveFailed(status)
        }
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Keychain Error

nonisolated enum KeychainError: Error {
    case saveFailed(OSStatus)
}

// MARK: - TokenProviding Conformance

extension KeychainTokenStore: TokenProviding {}
