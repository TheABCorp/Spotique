import Foundation
import Testing
@testable import Spotique

struct AuthDestinationValidationTests {
    @Test(arguments: [
        "3475551234",
        "(347) 555-1234",
        "347.555.1234",
        "1-347-555-1234",
        "+1 347 555 1234",
        "+13475551234",
    ])
    func acceptsUSPhoneFormats(input: String) {
        #expect(AuthDestination.phone(fromInput: input) == .phone("+13475551234"))
    }

    @Test(arguments: [
        "",
        "347555123",          // 9 digits
        "23475551234",        // 11 digits, not a leading 1
        "+44 20 7946 0958",   // non-US
        "347555123456",       // 12 digits
        "phone",
    ])
    func rejectsInvalidPhones(input: String) {
        #expect(AuthDestination.phone(fromInput: input) == nil)
    }

    @Test func emailIsTrimmedAndLowercased() {
        #expect(AuthDestination.email(fromInput: "  Jane.Doe@Example.COM \n") == .email("jane.doe@example.com"))
    }

    @Test(arguments: ["", "jane", "a@b", "@example.com", "a b@example.com", "a@@example.com", "a@.com", "a@example."])
    func rejectsInvalidEmails(input: String) {
        #expect(AuthDestination.email(fromInput: input) == nil)
    }

    @Test func reportsMedium() {
        #expect(AuthDestination.phone("+13475551234").medium == .phone)
        #expect(AuthDestination.email("a@example.com").medium == .email)
    }
}

struct AuthErrorMapperTests {
    @Test func offlineMapsToOfflineForEveryStep() {
        for step in [AuthStep.sendCode, .verify, .completeProfile] {
            #expect(AuthErrorMapper.failure(for: APIError.offline, step: step) == .offline)
        }
    }

    @Test func rateLimitDependsOnStep() {
        #expect(AuthErrorMapper.failure(for: APIError.rateLimited, step: .sendCode) == .rateLimited)
        #expect(AuthErrorMapper.failure(for: APIError.rateLimited, step: .verify) == .tooManyAttempts)
    }

    @Test func sendCodeRejectionMapsToInvalidDestination() {
        let validation = APIError.validation(message: "Must be a valid email address", fields: [:])
        #expect(AuthErrorMapper.failure(for: validation, step: .sendCode) == .invalidDestination)
        #expect(AuthErrorMapper.failure(for: APIError.unknown(statusCode: 400), step: .sendCode) == .invalidDestination)
    }

    @Test func wrongCodeMapsToInvalidCode() {
        let error = APIError.unauthorized(message: "Invalid code. Please try again.")
        #expect(AuthErrorMapper.failure(for: error, step: .verify) == .invalidCode)
    }

    @Test func missingCodeMapsToExpired() {
        let error = APIError.unauthorized(message: "No active verification code found. Request a new one.")
        #expect(AuthErrorMapper.failure(for: error, step: .verify) == .codeExpired)
    }

    @Test func profileValidationKeepsFieldErrors() {
        let fields = ["first_name": ["can't be blank"]]
        let error = APIError.validation(message: "Validation failed", fields: fields)
        #expect(AuthErrorMapper.failure(for: error, step: .completeProfile) == .invalidFields(fields))
    }

    @Test func profileConflictMapsToAlreadyCompleted() {
        let error = APIError.conflict(code: nil, message: "Profile already completed")
        #expect(AuthErrorMapper.failure(for: error, step: .completeProfile) == .profileAlreadyCompleted)
    }

    @Test func unexpectedErrorsAreGeneric() {
        #expect(AuthErrorMapper.failure(for: APIError.server, step: .verify) == .generic)
        #expect(AuthErrorMapper.failure(for: CancellationError(), step: .sendCode) == .generic)
    }

    @Test func everyFailureHasAMessage() {
        let failures: [AuthFailure] = [
            .invalidDestination, .rateLimited, .invalidCode, .codeExpired, .tooManyAttempts,
            .invalidFields([:]), .profileAlreadyCompleted, .offline, .generic,
        ]
        for failure in failures {
            #expect(!failure.message.isEmpty)
        }
    }
}

struct UserProfileCompletenessTests {
    @Test func completeUserIsComplete() {
        let address = Address(
            id: UUID(), label: .home, street: "34-15 74th Street", city: "Jackson Heights",
            state: "NY", zip: "11372", latitude: nil, longitude: nil
        )
        let user = User(
            id: TestHelpers.sampleUserID, phone: "+13475551234", email: nil, firstName: "Jane",
            lastName: "Doe", role: .host, addresses: [address],
            createdAt: .now, updatedAt: .now
        )
        #expect(user.isProfileComplete)
    }

    @Test func userWithoutAddressOrRoleIsIncomplete() {
        #expect(!TestHelpers.makeUser().isProfileComplete)  // no addresses
        #expect(!TestHelpers.makeUser(role: nil).isProfileComplete)
        #expect(!TestHelpers.makeUser(firstName: "").isProfileComplete)
    }
}
