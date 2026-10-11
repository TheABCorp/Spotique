import Foundation
import Testing
@testable import Spotique

@Suite(.serialized)
struct UserServiceTests {
    private let baseURL = URL(string: "https://api.example.com/api/v1")!

    private func makeService() -> LiveUserService {
        let apiClient = APIClient(
            session: StubURLProtocol.session(),
            configuration: APIConfiguration(baseURL: baseURL),
            tokenProvider: InMemoryTokenStore(token: "test-token", userID: Fixtures.userID),
            onUnauthorized: {}
        )
        return LiveUserService(apiClient: apiClient)
    }

    @Test func userFetchesByID() async throws {
        StubURLProtocol.respond { _ in (200, Data(Fixtures.userResponseJSON.utf8)) }

        let user = try await makeService().user(id: Fixtures.userID)

        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/api/v1/users/550e8400-e29b-41d4-a716-446655440001")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(user.id == Fixtures.userID)
        #expect(user.firstName == "Jane")
        #expect(user.role == .host)
    }

    @Test func userDecodesAddresses() async throws {
        StubURLProtocol.respond { _ in (200, Data(Fixtures.userResponseJSON.utf8)) }

        let user = try await makeService().user(id: Fixtures.userID)

        let address = try #require(user.addresses.first)
        #expect(address.label == .home)
        #expect(address.street == "34-15 74th Street")
        #expect(address.zip == "11372")
        #expect(address.latitude == 40.7505)
    }

    @Test func updateUserSendsOnlyProvidedFields() async throws {
        StubURLProtocol.respond { _ in (200, Data(Fixtures.userResponseJSON.utf8)) }

        _ = try await makeService().updateUser(id: Fixtures.userID, UserUpdateInput(role: .both))

        let request = try #require(StubURLProtocol.capturedRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/v1/users/550e8400-e29b-41d4-a716-446655440001")
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
        #expect(json == ["user": ["role": "both"]])
    }

    @Test func updateUserEncodesNamesInSnakeCase() async throws {
        StubURLProtocol.respond { _ in (200, Data(Fixtures.userResponseJSON.utf8)) }

        _ = try await makeService().updateUser(
            id: Fixtures.userID,
            UserUpdateInput(firstName: "Janet", lastName: "Dough")
        )

        let body = try #require(StubURLProtocol.capturedRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
        #expect(json == ["user": ["first_name": "Janet", "last_name": "Dough"]])
    }

    @Test func userMapsProfileIncompleteError() async {
        let body = #"{"error":{"code":"profile_incomplete","message":"Please complete your profile."}}"#
        StubURLProtocol.respond { _ in (403, Data(body.utf8)) }

        await #expect(throws: APIError.profileIncomplete) {
            try await makeService().user(id: Fixtures.userID)
        }
    }

    @Test func updateUserMapsValidationError() async {
        let body = #"{"error":{"message":"Validation failed","details":{"first_name":["can't be blank"]}}}"#
        StubURLProtocol.respond { _ in (422, Data(body.utf8)) }

        await #expect(throws: APIError.validation(message: "Validation failed", fields: ["first_name": ["can't be blank"]])) {
            try await makeService().updateUser(id: Fixtures.userID, UserUpdateInput(firstName: ""))
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
