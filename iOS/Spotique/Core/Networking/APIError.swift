import Foundation

enum APIError: Error, Equatable, Sendable {
    case unauthorized(message: String?)
    case profileIncomplete
    case forbidden(code: String?)
    case notFound
    case validation(message: String?, fields: [String: [String]])
    case conflict(code: String?, message: String?)
    case rateLimited
    case offline
    case server
    case decoding(description: String)
    case unknown(statusCode: Int)

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case let (.unauthorized(l), .unauthorized(r)):
            return l == r
        case (.profileIncomplete, .profileIncomplete):
            return true
        case let (.forbidden(l), .forbidden(r)):
            return l == r
        case (.notFound, .notFound):
            return true
        case let (.validation(lm, lf), .validation(rm, rf)):
            return lm == rm && lf == rf
        case let (.conflict(lc, lm), .conflict(rc, rm)):
            return lc == rc && lm == rm
        case (.rateLimited, .rateLimited):
            return true
        case (.offline, .offline):
            return true
        case (.server, .server):
            return true
        case let (.decoding(l), .decoding(r)):
            return l == r
        case let (.unknown(l), .unknown(r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - LocalizedError

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return String(localized: "Your session has expired. Please sign in again.")
        case .profileIncomplete:
            return String(localized: "Please complete your profile to continue.")
        case .forbidden:
            return String(localized: "You don't have permission to do that.")
        case .notFound:
            return String(localized: "The requested item could not be found.")
        case let .validation(message, _):
            return message ?? String(localized: "Please check your input and try again.")
        case let .conflict(_, message):
            return message ?? String(localized: "This conflicts with an existing booking.")
        case .rateLimited:
            return String(localized: "Too many requests. Please wait a moment and try again.")
        case .offline:
            return String(localized: "No internet connection. Please check your network and try again.")
        case .server:
            return String(localized: "Something went wrong on our end. Please try again later.")
        case .decoding:
            return String(localized: "We received an unexpected response. Please try again.")
        case .unknown:
            return String(localized: "Something went wrong. Please try again.")
        }
    }
}

// MARK: - Server Error Body

struct ServerErrorBody: Decodable, Sendable {
    let error: ErrorDetail

    struct ErrorDetail: Decodable, Sendable {
        let code: String?
        let message: String?
        let details: [String: [String]]?
    }
}

// MARK: - Parsing

extension APIError {
    static func from(statusCode: Int, data: Data) -> APIError {
        let body = try? JSONCoding.decoder.decode(ServerErrorBody.self, from: data)
        let code = body?.error.code
        let message = body?.error.message
        let details = body?.error.details ?? [:]

        switch statusCode {
        case 401:
            return .unauthorized(message: message)
        case 403 where code == "profile_incomplete":
            return .profileIncomplete
        case 403:
            return .forbidden(code: code)
        case 404:
            return .notFound
        case 409:
            return .conflict(code: code, message: message)
        case 422:
            return .validation(message: message, fields: details)
        case 429:
            return .rateLimited
        case 500...599:
            return .server
        default:
            return .unknown(statusCode: statusCode)
        }
    }
}
