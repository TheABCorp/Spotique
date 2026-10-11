import Foundation

/// Mirrors the API address object (Api/app/serializers/user_serializer.rb).
nonisolated struct Address: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let label: AddressLabel?
    let street: String
    let city: String
    let state: String
    let zip: String
    let latitude: Double?
    let longitude: Double?
}

nonisolated enum AddressLabel: String, Codable, Sendable, Hashable, CaseIterable {
    case home
    case work
    case other
}

/// Address sent to `POST /auth/complete-profile`.
nonisolated struct AddressInput: Encodable, Sendable, Equatable {
    var label: AddressLabel?
    var street: String
    var city: String
    var state: String
    var zip: String
    var latitude: Double?
    var longitude: Double?
}
