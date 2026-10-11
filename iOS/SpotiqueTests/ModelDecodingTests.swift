import Testing
import Foundation
@testable import Spotique

struct ModelDecodingTests {
    @Test func decodesUser() throws {
        let json = """
        {"id":"550e8400-e29b-41d4-a716-446655440001","phone":"+13475551234","email":null,"first_name":"Jane","last_name":"Doe","role":"host","addresses":[],"created_at":"2025-01-15T10:00:00Z","updated_at":"2025-01-15T10:00:00Z"}
        """.data(using: .utf8)!

        let user = try JSONCoding.decoder.decode(User.self, from: json)
        #expect(user.id == TestHelpers.sampleUserID)
        #expect(user.firstName == "Jane")
        #expect(user.role == .host)
        #expect(user.isHost == true)
        #expect(user.isDriver == false)
        #expect(user.displayName == "Jane D")
    }

    @Test func decodesIncompleteUser() throws {
        let json = """
        {"id":"550e8400-e29b-41d4-a716-446655440003","phone":"+13475559999","email":null,"first_name":null,"last_name":null,"role":null,"addresses":[],"created_at":"2025-01-15T10:00:00Z","updated_at":"2025-01-15T10:00:00Z"}
        """.data(using: .utf8)!

        let user = try JSONCoding.decoder.decode(User.self, from: json)
        #expect(user.firstName == nil)
        #expect(user.role == nil)
        #expect(user.isHost == false)
        #expect(user.isDriver == false)
    }

    @Test func decodesUserAddresses() throws {
        let envelope = try JSONCoding.decoder.decode(DataEnvelope<User>.self, from: TestHelpers.fixtureData("user"))

        let address = try #require(envelope.data.addresses.first)
        #expect(address.label == .home)
        #expect(address.city == "Jackson Heights")
        #expect(address.longitude == -73.8915)
    }

    @Test func rejectsUnknownRole() {
        let roleJSON = "\"superuser\"".data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONCoding.decoder.decode(UserRole.self, from: roleJSON)
        }
    }

    @Test func decodesFractionalSecondsDate() throws {
        let json = """
        {"id":"550e8400-e29b-41d4-a716-446655440001","phone":null,"email":"a@example.com","first_name":"A","last_name":"B","role":"driver","addresses":[],"created_at":"2025-01-15T10:00:00.123Z","updated_at":"2025-01-15T10:00:00Z"}
        """.data(using: .utf8)!

        let user = try JSONCoding.decoder.decode(User.self, from: json)
        #expect(abs(user.createdAt.timeIntervalSince1970 - 1_736_935_200.123) < 0.001)
    }

    @Test func decodesVerifyResultExisting() throws {
        let envelope = try JSONCoding.decoder.decode(
            DataEnvelope<VerifyResult>.self,
            from: TestHelpers.fixtureData("verify-existing")
        )

        #expect(envelope.data.id == TestHelpers.sampleUserID)
        #expect(envelope.data.isNew == false)
        #expect(envelope.data.user?.firstName == "Jane")
    }

    @Test func decodesVerifyResultNew() throws {
        let envelope = try JSONCoding.decoder.decode(
            DataEnvelope<VerifyResult>.self,
            from: TestHelpers.fixtureData("verify-new")
        )

        #expect(envelope.data.isNew == true)
        #expect(envelope.data.user == nil)
    }
}
