import Foundation
@testable import Spotique

enum TestHelpers {
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
        let urlSession = session ?? stubSession()
        return APIClient(
            session: urlSession,
            configuration: .debug,
            tokenProvider: tokenStore,
            onUnauthorized: onUnauthorized
        )
    }

    static let sampleUser = User(
        id: "uid_abc123",
        phone: "+13475551234",
        email: nil,
        firstName: "Jane",
        lastName: "Doe",
        address: "34-15 74th Street, Jackson Heights, NY 11372",
        role: .host,
        ratingPositivePct: 94,
        ratingCount: 17,
        noShowCount: 0,
        createdAt: Date(timeIntervalSince1970: 1736935200),
        paymentMethodText: nil
    )
}

private class BundleToken {}
