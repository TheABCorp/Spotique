import Foundation

enum JSONCoding {
    nonisolated static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoFormatterNoFraction = ISO8601DateFormatter()
        isoFormatterNoFraction.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = isoFormatter.date(from: string) {
                return date
            }
            if let date = isoFormatterNoFraction.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        return decoder
    }()

    nonisolated static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
