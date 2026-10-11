import Foundation
import OSLog

/// Last signup step: who the user is, their home address, and whether they
/// host, drive, or both. On success `SessionStore` moves to signed in.
@Observable
@MainActor
final class ProfileCompletionViewModel {
    enum State: Equatable {
        case idle
        case submitting
        case failed(AuthFailure)
    }

    enum Field: Hashable {
        case firstName, lastName, street, city, state, zip, role
    }

    static let maxNameLength = 50

    var firstName = ""
    var lastName = ""
    var street = ""
    // MVP serves Jackson Heights (11372); prefilled but editable.
    var city = "Jackson Heights"
    var stateCode = "NY"
    var zip = "11372"
    var role: UserRole?
    private(set) var state: State = .idle
    /// Errors returned by the server for specific fields (422).
    private(set) var serverErrors: [Field: String] = [:]

    private let authService: any AuthServicing
    private let sessionStore: SessionStore

    init(authService: any AuthServicing, sessionStore: SessionStore) {
        self.authService = authService
        self.sessionStore = sessionStore
    }

    var failure: AuthFailure? {
        if case .failed(let failure) = state { failure } else { nil }
    }

    /// Client rule errors show as soon as they apply (e.g. a name over 50
    /// characters); empty required fields just keep the button disabled.
    func error(for field: Field) -> String? {
        clientError(for: field) ?? serverErrors[field]
    }

    var isValid: Bool {
        let required = [firstName, lastName, street, city, stateCode, zip].map(trimmed)
        let hasClientErrors = [Field.firstName, .lastName, .zip].contains { clientError(for: $0) != nil }
        return !required.contains(where: \.isEmpty) && role != nil && !hasClientErrors
    }

    private func clientError(for field: Field) -> String? {
        switch field {
        case .firstName, .lastName:
            let value = field == .firstName ? firstName : lastName
            if trimmed(value).count > Self.maxNameLength {
                return String(localized: "Must be 50 characters or fewer")
            }
        case .zip:
            if !trimmed(zip).isEmpty, !isValidZip(trimmed(zip)) {
                return String(localized: "Enter a 5-digit ZIP code")
            }
        default:
            break
        }
        return nil
    }

    var canSubmit: Bool {
        isValid && state != .submitting
    }

    func clearServerError(for field: Field) {
        serverErrors[field] = nil
    }

    // MARK: - Actions

    func submit() async {
        guard canSubmit, let role else { return }
        state = .submitting
        serverErrors = [:]

        let input = CompleteProfileInput(
            firstName: trimmed(firstName),
            lastName: trimmed(lastName),
            address: AddressInput(
                label: .home,
                street: trimmed(street),
                city: trimmed(city),
                state: trimmed(stateCode).uppercased(),
                zip: trimmed(zip)
            ),
            role: role
        )

        do {
            let user = try await authService.completeProfile(input)
            state = .idle
            sessionStore.profileCompleted(user: user)
        } catch is CancellationError {
            state = .idle
        } catch {
            await handle(AuthErrorMapper.failure(for: error, step: .completeProfile))
        }
    }

    func signOut() async {
        await sessionStore.signOut()
    }

    // MARK: - Private

    private func handle(_ failure: AuthFailure) async {
        Log.auth.error("complete-profile failed: \(String(describing: failure), privacy: .public)")
        if case .invalidFields(let fields) = failure {
            serverErrors = Self.fieldErrors(from: fields)
        }
        state = .failed(failure)
        // Already completed elsewhere: this session's view of the user is stale.
        if failure == .profileAlreadyCompleted {
            await sessionStore.signOut()
        }
    }

    /// Maps Rails `details` keys to form fields. A missing address object
    /// is reported as `address`, so it's shown on the street field.
    private static func fieldErrors(from details: [String: [String]]) -> [Field: String] {
        let keys: [String: Field] = [
            "first_name": .firstName, "last_name": .lastName, "role": .role,
            "address": .street, "street": .street, "city": .city, "state": .state, "zip": .zip,
        ]
        var errors: [Field: String] = [:]
        for (key, messages) in details {
            let name = key.split(separator: ".").last.map(String.init) ?? key
            guard let field = keys[name], let message = messages.first else { continue }
            errors[field] = String(localized: "This field \(message)")
        }
        return errors
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidZip(_ value: String) -> Bool {
        value.count == 5 && value.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
