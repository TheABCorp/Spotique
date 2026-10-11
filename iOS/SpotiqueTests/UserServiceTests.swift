import Foundation
import Testing
@testable import Spotique

extension NetworkTests {
    struct UserServiceTests {
        private let userPath = "/api/v1/users/550e8400-e29b-41d4-a716-446655440001"

        private func makeService() -> LiveUserService {
            let tokenStore = FakeTokenStore(token: "test-token", userID: TestHelpers.sampleUserID)
            return LiveUserService(apiClient: TestHelpers.makeAPIClient(tokenStore: tokenStore))
        }

        @Test func userFetchesByID() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, data: TestHelpers.fixtureData("user"))

            let user = try await makeService().user(id: TestHelpers.sampleUserID)

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == userPath)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(user.id == TestHelpers.sampleUserID)
            #expect(user.firstName == "Jane")
            #expect(user.role == .host)
        }

        @Test func userDecodesAddresses() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, data: TestHelpers.fixtureData("user"))

            let user = try await makeService().user(id: TestHelpers.sampleUserID)

            let address = try #require(user.addresses.first)
            #expect(address.label == .home)
            #expect(address.street == "34-15 74th Street")
            #expect(address.zip == "11372")
            #expect(address.latitude == 40.7505)
        }

        @Test func updateUserSendsOnlyProvidedFields() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, data: TestHelpers.fixtureData("user"))

            _ = try await makeService().updateUser(id: TestHelpers.sampleUserID, UserUpdateInput(role: .both))

            let request = try #require(StubURLProtocol.lastRequest)
            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.path == userPath)
            let body = try #require(request.httpBody)
            let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
            #expect(json == ["user": ["role": "both"]])
        }

        @Test func updateUserEncodesNamesInSnakeCase() async throws {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 200, data: TestHelpers.fixtureData("user"))

            _ = try await makeService().updateUser(
                id: TestHelpers.sampleUserID,
                UserUpdateInput(firstName: "Janet", lastName: "Dough")
            )

            let body = try #require(StubURLProtocol.lastRequest?.httpBody)
            let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
            #expect(json == ["user": ["first_name": "Janet", "last_name": "Dough"]])
        }

        @Test func userMapsProfileIncompleteError() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 403, json: #"{"error":{"code":"profile_incomplete","message":"Please complete your profile."}}"#)

            await #expect(throws: APIError.profileIncomplete) {
                try await makeService().user(id: TestHelpers.sampleUserID)
            }
        }

        @Test func updateUserMapsValidationError() async {
            StubURLProtocol.reset()
            StubURLProtocol.enqueue(statusCode: 422, data: TestHelpers.fixtureData("error-validation"))

            let expected = APIError.validation(
                message: "Validation failed",
                fields: ["first_name": ["is required"], "role": ["is not included in the list"]]
            )
            await #expect(throws: expected) {
                try await makeService().updateUser(id: TestHelpers.sampleUserID, UserUpdateInput(firstName: ""))
            }
        }
    }
}

struct CompleteProfileInputTests {
    @Test func encodesAddressAsObject() throws {
        let input = CompleteProfileInput(
            firstName: "Jane",
            lastName: "Doe",
            address: AddressInput(
                label: .home,
                street: "34-15 74th Street",
                city: "Jackson Heights",
                state: "NY",
                zip: "11372"
            ),
            role: .host
        )

        let data = try JSONCoding.encoder.encode(input)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let address = try #require(json["address"] as? [String: Any])

        #expect(json["first_name"] as? String == "Jane")
        #expect(address["street"] as? String == "34-15 74th Street")
        #expect(address["label"] as? String == "home")
        #expect(address["latitude"] == nil)
    }
}
