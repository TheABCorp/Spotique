import Foundation

/// How the user chooses to receive their verification code.
nonisolated enum AuthMedium: String, CaseIterable, Sendable {
    case phone
    case email
}

nonisolated extension AuthDestination {
    /// Builds a US phone destination from free-form input such as
    /// `(347) 555-1234`, `1-347-555-1234`, or `+13475551234`.
    /// Returns nil unless the input holds exactly 10 digits after an
    /// optional leading country code `1`. Output matches the API's `+1XXXXXXXXXX`.
    static func phone(fromInput input: String) -> AuthDestination? {
        var digits = input.filter { $0.isASCII && $0.isNumber }
        if digits.count == 11, digits.first == "1" {
            digits.removeFirst()
        }
        guard digits.count == 10 else { return nil }
        return .phone("+1" + digits)
    }

    /// Builds an email destination, trimmed and lowercased (the API stores
    /// email case-insensitively). The server remains the final validator.
    static func email(fromInput input: String) -> AuthDestination? {
        let email = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2,
              !email.contains(where: \.isWhitespace) else { return nil }

        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty,
              domain.contains("."),
              !domain.hasPrefix("."),
              !domain.hasSuffix(".") else { return nil }
        return .email(email)
    }

    var medium: AuthMedium {
        switch self {
        case .phone: .phone
        case .email: .email
        }
    }
}
