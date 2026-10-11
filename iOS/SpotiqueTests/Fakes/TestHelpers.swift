import Foundation
@testable import Spotique

enum TestHelpers {
    static let baseURL = URL(string: "http://localhost:3000/api/v1")!
    static let sampleUserID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440001")!

    static func fixtureData(_ name: String) -> Data {
        let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json", subdirectory: nil)
            ?? Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")!
        return try! Data(contentsOf: url)
    }

    static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    static func makeAPIClient(
        session: URLSession? = nil,
        tokenStore: FakeTokenStore = FakeTokenStore(),
        onUnauthorized: @escaping @Sendable @MainActor () -> Void = {}
    ) -> APIClient {
        APIClient(
            session: session ?? stubSession(),
            configuration: APIConfiguration(baseURL: baseURL),
            tokenProvider: tokenStore,
            onUnauthorized: onUnauthorized
        )
    }

    static func makeUser(id: UUID = sampleUserID, firstName: String? = "Jane", role: UserRole? = .host) -> User {
        User(
            id: id,
            phone: "+13475551234",
            email: nil,
            firstName: firstName,
            lastName: "Doe",
            role: role,
            addresses: [],
            createdAt: Date(timeIntervalSince1970: 1_736_935_200),
            updatedAt: Date(timeIntervalSince1970: 1_736_935_200)
        )
    }

    static let sampleUser = makeUser()
}

private class BundleToken {}
