import Testing
import Foundation
@testable import Spotique

extension NetworkTests {
    struct APIClientTests {
        private let userJSON = """
            {"data":{"id":"550e8400-e29b-41d4-a716-446655440001","phone":null,"email":"a@example.com","first_name":"A","last_name":"B","role":"driver","addresses":[],"created_at":"2025-01-15T10:00:00Z","updated_at":"2025-01-15T10:00:00Z"}}
            """
        private let userPath = "/users/550e8400-e29b-41d4-a716-446655440001"

        @Test func unwrapsEnvelope() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, json: userJSON)

            let client = TestHelpers.makeAPIClient()
            let user: User = try await client.send(Endpoint(method: .get, path: userPath))

            #expect(user.id == TestHelpers.sampleUserID)
        }

        @Test func attachesAuthHeader() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, json: userJSON)

            let tokenStore = FakeTokenStore(token: "test-token", userID: TestHelpers.sampleUserID)
            let client = TestHelpers.makeAPIClient(tokenStore: tokenStore)
            let _: User = try await client.send(Endpoint(method: .get, path: userPath))

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        }

        @Test func omitsAuthHeaderWhenNotRequired() {
            let endpoint = Endpoint(method: .post, path: "/auth/verify", requiresAuth: false)
            let request = endpoint.urlRequest(baseURL: TestHelpers.baseURL, token: "some-token")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        }

        @Test func maps401ToUnauthorizedAndNotifies() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 401, json: #"{"error":{"code":"unauthorized","message":"Invalid token"}}"#)

            let flag = CallFlag()
            let client = TestHelpers.makeAPIClient(onUnauthorized: { flag.called = true })

            await #expect(throws: APIError.unauthorized(message: "Invalid token")) {
                let _: User = try await client.send(Endpoint(method: .get, path: userPath))
            }
            #expect(await flag.called)
        }

        @Test func maps403ProfileIncomplete() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 403, json: #"{"error":{"code":"profile_incomplete","message":"Complete your profile"}}"#)

            let client = TestHelpers.makeAPIClient()

            await #expect(throws: APIError.profileIncomplete) {
                let _: User = try await client.send(Endpoint(method: .get, path: userPath))
            }
        }

        @Test func maps403Forbidden() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 403, json: #"{"error":{"code":"forbidden","message":"You can only access your own user record."}}"#)

            let client = TestHelpers.makeAPIClient()

            await #expect(throws: APIError.forbidden(code: "forbidden")) {
                let _: User = try await client.send(Endpoint(method: .get, path: "/users/someone-else"))
            }
        }

        @Test func maps409Conflict() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 409, data: TestHelpers.fixtureData("error-conflict"))

            let client = TestHelpers.makeAPIClient()

            await #expect(throws: APIError.conflict(code: "booking_conflict", message: "Time window overlaps an existing booking")) {
                let _: User = try await client.send(Endpoint(method: .post, path: "/auth/complete-profile"))
            }
        }

        @Test func maps422Validation() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 422, json: """
                {"error":{"code":"validation_failed","message":"Validation failed","details":{"first_name":["is required"]}}}
                """)

            let client = TestHelpers.makeAPIClient()

            await #expect(throws: APIError.validation(message: "Validation failed", fields: ["first_name": ["is required"]])) {
                let _: User = try await client.send(Endpoint(method: .post, path: "/auth/complete-profile"))
            }
        }

        @Test func maps429RateLimited() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 429, json: "{}")

            let client = TestHelpers.makeAPIClient()

            await #expect(throws: APIError.rateLimited) {
                let _: SendCodeResult = try await client.send(Endpoint(method: .post, path: "/auth/send-code", requiresAuth: false))
            }
        }

        @Test func mapsDecodingError() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, json: #"{"data": "not an object"}"#)

            let client = TestHelpers.makeAPIClient()

            do {
                let _: User = try await client.send(Endpoint(method: .get, path: userPath))
                Issue.record("Expected error")
            } catch let error as APIError {
                guard case .decoding = error else {
                    Issue.record("Expected decoding error, got \(error)")
                    return
                }
            } catch {
                Issue.record("Expected APIError, got \(error)")
            }
        }

        @Test func skipsUnauthorizedHandlerWhenHandlesUnauthorizedFalse() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 401, json: #"{"error":{"code":"unauthorized","message":"Invalid code"}}"#)

            let flag = CallFlag()
            let client = TestHelpers.makeAPIClient(onUnauthorized: { flag.called = true })
            let endpoint = Endpoint(method: .post, path: "/auth/verify", requiresAuth: false, handlesUnauthorized: false)

            await #expect(throws: APIError.self) {
                let _: VerifyResult = try await client.send(endpoint)
            }
            #expect(await !flag.called)
        }
    }
}

/// Records whether a main-actor callback ran.
@MainActor
private final class CallFlag {
    var called = false
}
