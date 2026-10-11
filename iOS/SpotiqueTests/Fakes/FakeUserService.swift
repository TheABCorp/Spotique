@testable import Spotique

final class FakeUserService: UserServicing, @unchecked Sendable {
    var currentUserResult: Result<User, Error> = .failure(APIError.server)
    var updateResult: Result<User, Error> = .failure(APIError.server)
    var deleteAccountError: Error?

    func currentUser() async throws -> User {
        try currentUserResult.get()
    }

    func update(_ fields: UserUpdateInput) async throws -> User {
        try updateResult.get()
    }

    func deleteAccount() async throws {
        if let error = deleteAccountError {
            throw error
        }
    }
}
