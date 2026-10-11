import Foundation
import Synchronization
@testable import Spotique

final class FakeTokenStore: TokenStoring, TokenProviding {
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
