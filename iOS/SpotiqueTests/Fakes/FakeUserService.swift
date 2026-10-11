import Foundation
@testable import Spotique

struct FakeUserService: UserServicing {
    var userResult: Result<User, Error> = .failure(APIError.server)
    var updateResult: Result<User, Error> = .failure(APIError.server)
    var deleteAccountError: Error?

    func user(id: UUID) async throws -> User {
        try userResult.get()
    }

    func updateUser(id: UUID, _ fields: UserUpdateInput) async throws -> User {
        try updateResult.get()
    }

    func deleteAccount() async throws {
        if let error = deleteAccountError {
            throw error
        }
    }
}
