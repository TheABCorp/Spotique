import Foundation

struct Endpoint: Sendable {
    let method: HTTPMethod
    let path: String
    var queryItems: [URLQueryItem]?
    var body: (any Encodable & Sendable)?
    var requiresAuth: Bool = true
    var handlesUnauthorized: Bool = true

    enum HTTPMethod: String, Sendable {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    func urlRequest(baseURL: URL, token: String?) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems?.isEmpty == false ? queryItems : nil

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 15

        if let body {
            request.httpBody = try? JSONCoding.encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

// MARK: - Type-Erased Encodable

private struct AnyEncodable: Encodable, @unchecked Sendable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        _encode = { encoder in try value.encode(to: encoder) }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
