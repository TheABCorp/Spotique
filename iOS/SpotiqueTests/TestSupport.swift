import Foundation
import Synchronization
@testable import Spotique

// MARK: - Fixtures

enum Fixtures {
    static let userID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440001")!

    static func user(id: UUID = userID, firstName: String? = "Jane", role: UserRole? = .host) -> User {
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

    /// A `GET`/`PATCH /users/:id` response body, matching UserSerializer.
    static let userResponseJSON = """
    {
      "data": {
        "id": "550e8400-e29b-41d4-a716-446655440001",
        "phone": "+13475551234",
        "email": null,
        "first_name": "Jane",
        "last_name": "Doe",
        "role": "host",
        "addresses": [
          {
            "id": "660e8400-e29b-41d4-a716-446655440001",
            "label": "home",
            "street": "34-15 74th Street",
            "city": "Jackson Heights",
            "state": "NY",
            "zip": "11372",
            "latitude": 40.7505,
            "longitude": -73.8915
          }
        ],
        "created_at": "2025-01-15T10:00:00Z",
        "updated_at": "2025-01-15T10:00:00Z"
      }
    }
    """
}

// MARK: - In-Memory Token Store

final class InMemoryTokenStore: TokenStoring, TokenProviding {
    private let storage: Mutex<(token: String?, userID: UUID?)>

    init(token: String? = nil, userID: UUID? = nil) {
        storage = Mutex((token, userID))
    }

    func token() -> String? { storage.withLock { $0.token } }
    func userID() -> UUID? { storage.withLock { $0.userID } }

    func save(token: String, userID: UUID) throws {
        storage.withLock { $0 = (token, userID) }
    }

    func clear() {
        storage.withLock { $0 = (nil, nil) }
    }
}

// MARK: - Stub User Service

struct StubUserService: UserServicing {
    var result: Result<User, APIError>

    func user(id: UUID) async throws -> User {
        try result.get()
    }

    func updateUser(id: UUID, _ fields: UserUpdateInput) async throws -> User {
        try result.get()
    }

    func deleteAccount() async throws {}
}

// MARK: - Stub URL Protocol

/// Intercepts requests from a `URLSession` built with `StubURLProtocol.session()`.
/// Tests using it must run serialized, since the handler is shared.
final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) -> (statusCode: Int, body: Data)

    private static let handler = Mutex<Handler?>(nil)
    private static let lastRequest = Mutex<URLRequest?>(nil)

    static func respond(with handler: @escaping Handler) {
        self.handler.withLock { $0 = handler }
        lastRequest.withLock { $0 = nil }
    }

    static var capturedRequest: URLRequest? {
        lastRequest.withLock { $0 }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        captured.httpBody = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        Self.lastRequest.withLock { $0 = captured }

        guard let handler = Self.handler.withLock({ $0 }), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (statusCode, body) = handler(captured)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
