import Foundation
import SwiftData

enum ModelContainerFactory {
    /// The shared persistent container. Cache models are registered
    /// by the plans that create them (e.g. CachedListing, CachedBooking).
    static let shared: ModelContainer = {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// In-memory container for tests and previews.
    static var inMemory: ModelContainer {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}
