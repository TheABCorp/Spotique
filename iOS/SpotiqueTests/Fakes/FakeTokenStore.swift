@testable import Spotique

final class FakeTokenStore: TokenStoring, @unchecked Sendable {
    private var storedToken: String?

    func token() -> String? { storedToken }

    func save(_ token: String) throws {
        storedToken = token
    }

    func clear() {
        storedToken = nil
    }
}
