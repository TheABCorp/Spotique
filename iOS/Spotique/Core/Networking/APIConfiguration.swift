import Foundation

struct APIConfiguration: Sendable {
    let baseURL: URL

    static let debug = APIConfiguration(
        baseURL: URL(string: "http://localhost:3000/api/v1")!
    )

    static let release: APIConfiguration = {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
            ?? "https://api.spotique.app/api/v1"
        return APIConfiguration(baseURL: URL(string: urlString)!)
    }()

    static var current: APIConfiguration {
        #if DEBUG
        .debug
        #else
        .release
        #endif
    }
}
