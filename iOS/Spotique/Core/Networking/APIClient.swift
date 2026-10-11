import Foundation

// MARK: - Token Provider

protocol TokenProviding: Sendable {
    func token() -> String?
}

// MARK: - API Client

final class APIClient: Sendable {
    private let session: URLSession
    private let configuration: APIConfiguration
    private let tokenProvider: any TokenProviding
    private let onUnauthorized: @Sendable @MainActor () -> Void

    init(
        session: URLSession = .shared,
        configuration: APIConfiguration = .current,
        tokenProvider: any TokenProviding,
        onUnauthorized: @escaping @Sendable @MainActor () -> Void
    ) {
        self.session = session
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.onUnauthorized = onUnauthorized
    }

    // MARK: - Send (with response body)

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let (data, statusCode) = try await performRequest(endpoint)

        guard (200...299).contains(statusCode) else {
            try await handleError(statusCode: statusCode, data: data, endpoint: endpoint)
        }

        do {
            let envelope = try JSONCoding.decoder.decode(DataEnvelope<T>.self, from: data)
            return envelope.data
        } catch {
            throw APIError.decoding(description: String(describing: error))
        }
    }

    // MARK: - Send (no response body, e.g. 204)

    func sendEmpty(_ endpoint: Endpoint) async throws {
        let (data, statusCode) = try await performRequest(endpoint)

        guard (200...299).contains(statusCode) else {
            try await handleError(statusCode: statusCode, data: data, endpoint: endpoint)
        }
    }

    // MARK: - Paged Send

    func sendPaged<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> PagedResponse<T> {
        let (data, statusCode) = try await performRequest(endpoint)

        guard (200...299).contains(statusCode) else {
            try await handleError(statusCode: statusCode, data: data, endpoint: endpoint)
        }

        do {
            return try JSONCoding.decoder.decode(PagedResponse<T>.self, from: data)
        } catch {
            throw APIError.decoding(description: String(describing: error))
        }
    }

    // MARK: - Private

    private func performRequest(_ endpoint: Endpoint) async throws -> (Data, Int) {
        let request = endpoint.urlRequest(
            baseURL: configuration.baseURL,
            token: tokenProvider.token()
        )

        Log.network.debug("→ \(endpoint.method.rawValue) \(endpoint.path)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut:
                throw APIError.offline
            default:
                throw APIError.unknown(statusCode: 0)
            }
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        Log.network.debug("← \(statusCode) \(endpoint.path)")

        return (data, statusCode)
    }

    @discardableResult
    private func handleError(statusCode: Int, data: Data, endpoint: Endpoint) async throws -> Never {
        let apiError = APIError.from(statusCode: statusCode, data: data)
        if case .unauthorized = apiError,
           endpoint.requiresAuth,
           endpoint.handlesUnauthorized {
            await onUnauthorized()
        }
        throw apiError
    }
}

// MARK: - Envelope Types

struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

struct PagedResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: [T]
    let meta: Meta

    struct Meta: Decodable, Sendable {
        let pagination: Pagination
    }

    struct Pagination: Decodable, Sendable {
        let page: Int
        let perPage: Int
        let total: Int
    }
}
