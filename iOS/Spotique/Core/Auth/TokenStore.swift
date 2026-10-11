import Foundation
import Security

// MARK: - Protocol

protocol TokenStoring: Sendable {
    func token() -> String?
    func save(_ token: String) throws
    func clear()
}

// MARK: - Keychain Implementation

struct KeychainTokenStore: TokenStoring, Sendable {
    private let service: String
    private let account = "auth-token"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.actionman.Spotique") {
        self.service = service
    }

    func token() -> String? {
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

    func save(_ token: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        clear()

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

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Keychain Error

enum KeychainError: Error {
    case saveFailed(OSStatus)
}

// MARK: - TokenProviding Conformance

extension KeychainTokenStore: TokenProviding {}
