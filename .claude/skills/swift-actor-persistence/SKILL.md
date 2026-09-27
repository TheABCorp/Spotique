---
name: swift-actor-persistence
description: Thread-safe data persistence in Swift using actors — in-memory cache with file-backed storage, eliminating data races by design.
---

# Swift Actors for Thread-Safe Persistence

Patterns for building thread-safe data persistence layers using Swift actors. Combines in-memory caching with file-backed storage, leveraging the actor model to eliminate data races at compile time.

## When to Activate

- Building a data persistence layer in Swift 5.5+
- Need thread-safe access to shared mutable state
- Want to eliminate manual synchronization (locks, DispatchQueues)
- Building offline-first apps with local storage

## Core Pattern

### Actor-Based Repository

The actor model guarantees serialized access — no data races, enforced by the compiler.

```swift
public actor LocalRepository<T: Codable & Identifiable> where T.ID == String {
    private var cache: [String: T] = [:]
    private let fileURL: URL

    public init(directory: URL = .documentsDirectory, filename: String = "data.json") {
        self.fileURL = directory.appendingPathComponent(filename)
        // Synchronous load during init (actor isolation not yet active)
        self.cache = Self.loadSynchronously(from: fileURL)
    }

    // MARK: - Public API

    public func save(_ item: T) throws {
        cache[item.id] = item
        try persistToFile()
    }

    public func delete(_ id: String) throws {
        cache[id] = nil
        try persistToFile()
    }

    public func find(by id: String) -> T? {
        cache[id]
    }

    public func loadAll() -> [T] {
        Array(cache.values)
    }

    // MARK: - Private

    private func persistToFile() throws {
        let data = try JSONEncoder().encode(Array(cache.values))
        try data.write(to: fileURL, options: .atomic)
    }

    private static func loadSynchronously(from url: URL) -> [String: T] {
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([T].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }
}
```

### Usage

All calls are automatically async due to actor isolation:

```swift
let repository = LocalRepository<Listing>()

// Read — fast O(1) lookup from in-memory cache
let listing = await repository.find(by: "lst-001")
let allListings = await repository.loadAll()

// Write — updates cache and persists to file atomically
try await repository.save(newListing)
try await repository.delete("lst-001")
```

### Combining with @Observable ViewModel

```swift
@Observable
final class ListingListViewModel {
    private(set) var listings: [Listing] = []
    private let repository: LocalRepository<Listing>

    init(repository: LocalRepository<Listing> = LocalRepository()) {
        self.repository = repository
    }

    func load() async {
        listings = await repository.loadAll()
    }

    func add(_ listing: Listing) async throws {
        try await repository.save(listing)
        listings = await repository.loadAll()
    }
}
```

## Spotique Context

- **SwiftData is the default** for local persistence in Spotique (see `iOS/CLAUDE.md`). Reach for this actor pattern only for simple file-backed caches that don't need SwiftData's querying or `@Query` integration — e.g. cached map listings for offline browsing, or an unsent booking-request draft.
- **Firestore is the source of truth** for listings, bookings, ratings, and user profiles. A local actor cache is a read-through/offline convenience, never the authority.
- **Privacy**: never persist a listing's full street address or a host's phone number to the file cache unless the booking is confirmed. Keep the cache to what the pre-booking map view is allowed to show.
- **Never store secrets** (auth tokens, verification codes) in the JSON file; use the Keychain.
- Models stored here must be `Codable & Identifiable & Sendable` with `String` IDs (Firestore document IDs).

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Actor (not class + lock) | Compiler-enforced thread safety, no manual synchronization |
| In-memory cache + file persistence | Fast reads from cache, durable writes to disk |
| Synchronous init loading | Avoids async initialization complexity |
| Dictionary keyed by ID | O(1) lookups by identifier |
| Generic over `Codable & Identifiable` | Reusable across any model type |
| Atomic file writes (`.atomic`) | Prevents partial writes on crash |

## Best Practices

- **Use `Sendable` types** for all data crossing actor boundaries
- **Keep the actor's public API minimal** — only expose domain operations, not persistence details
- **Use `.atomic` writes** to prevent data corruption if the app crashes mid-write
- **Load synchronously in `init`** — async initializers add complexity with minimal benefit for local files
- **Combine with `@Observable`** ViewModels for reactive UI updates

## Anti-Patterns to Avoid

- Using `DispatchQueue` or `NSLock` instead of actors for new Swift concurrency code
- Exposing the internal cache dictionary to external callers
- Making the file URL configurable without validation
- Forgetting that all actor method calls are `await` — callers must handle async context
- Using `nonisolated` to bypass actor isolation (defeats the purpose)

## When to Use

- Local data storage in iOS/macOS apps (user data, settings, cached content)
- Offline-first architectures that sync to a server later
- Any shared mutable state that multiple parts of the app access concurrently
- Replacing legacy `DispatchQueue`-based thread safety with modern Swift concurrency
