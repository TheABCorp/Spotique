import Foundation

nonisolated struct APIConfiguration: Sendable {
    let baseURL: URL

    /// Reads `API_BASE_URL` from Info.plist, which is set per build
    /// configuration in `iOS/Config/*.xcconfig`.
    static let current: APIConfiguration = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString),
              url.scheme != nil else {
            fatalError("API_BASE_URL is missing or invalid in Info.plist. Check iOS/Config/*.xcconfig.")
        }
        return APIConfiguration(baseURL: url)
    }()
}
