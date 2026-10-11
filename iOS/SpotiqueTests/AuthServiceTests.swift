import Foundation
import Testing
@testable import Spotique

extension NetworkTests {
    struct AuthServiceTests {
        private let sendCodeJSON = #"{"data":{"medium":"phone","masked":"+1347***1234","expires_in":600}}"#

        private func makeService(onUnauthorized: @escaping @Sendable @MainActor () -> Void = {}) -> LiveAuthService {
            let tokenStore = FakeTokenStore(token: "stored-token", userID: TestHelpers.sampleUserID)
            return LiveAuthService(apiClient: TestHelpers.makeAPIClient(tokenStore: tokenStore, onUnauthorized: onUnauthorized))
        }

        private func lastRequestJSON() throws -> [String: Any] {
            let body = try #require(StubURLProtocol.lastRequest?.httpBody)
            return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        }

        @Test func sendCodeSendsPhoneWithoutAuthHeader() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, json: sendCodeJSON)

            let result = try await makeService().sendCode(.phone("+13475551234"))

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/auth/send-code")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(try lastRequestJSON() as? [String: String] == ["phone": "+13475551234"])
            #expect(result.masked == "+1347***1234")
            #expect(result.expiresIn == 600)
        }

        @Test func sendCodeSendsEmail() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, json: sendCodeJSON)

            _ = try await makeService().sendCode(.email("jane@example.com"))

            #expect(try lastRequestJSON() as? [String: String] == ["email": "jane@example.com"])
        }

        @Test func verifySendsDestinationAndCode() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, data: TestHelpers.fixtureData("verify-new"))

            let result = try await makeService().verify(.phone("+13475551234"), code: "123456")

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.url?.path == "/api/v1/auth/verify")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(try lastRequestJSON() as? [String: String] == ["phone": "+13475551234", "code": "123456"])
            #expect(result.isNew)
            #expect(result.id == TestHelpers.sampleUserID)
            #expect(result.user == nil)
        }

        @Test func verifyDecodesExistingUser() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, data: TestHelpers.fixtureData("verify-existing"))

            let result = try await makeService().verify(.email("jane@example.com"), code: "123456")

            #expect(!result.isNew)
            #expect(result.user?.firstName == "Jane")
        }

        @Test func verify401DoesNotSignOut() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 401, json: #"{"error":{"message":"Invalid code. Please try again."}}"#)
            let flag = SignOutFlag()

            await #expect(throws: APIError.unauthorized(message: "Invalid code. Please try again.")) {
                try await makeService(onUnauthorized: { flag.called = true }).verify(.phone("+13475551234"), code: "000000")
            }
            #expect(await !flag.called)
        }

        @Test func completeProfileSendsAuthenticatedNestedBody() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 201, data: TestHelpers.fixtureData("user"))
            let input = CompleteProfileInput(
                firstName: "Jane",
                lastName: "Doe",
                address: AddressInput(street: "34-15 74th Street", city: "Jackson Heights", state: "NY", zip: "11372"),
                role: .driver
            )

            _ = try await makeService().completeProfile(input)

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.url?.path == "/api/v1/auth/complete-profile")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer stored-token")
            let user = try #require(try lastRequestJSON()["user"] as? [String: Any])
            #expect(user["first_name"] as? String == "Jane")
            #expect(user["role"] as? String == "driver")
            #expect((user["address"] as? [String: Any])?["zip"] as? String == "11372")
        }
    }
}

@MainActor
private final class SignOutFlag {
    var called = false
}
