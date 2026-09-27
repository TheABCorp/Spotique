# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spotique is an iOS app built with SwiftUI and SwiftData. It targets iOS 26.1, uses **Swift 6 language mode** (strict concurrency checking is on), and has bundle identifier `com.actionman.Spotique`. Minimum iOS is 26.1; use Xcode 26+.

## Build & Test Commands

```bash
# Build
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build

# Run unit tests
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpotiqueTests/SpotiqueTests/example test

# Clean build folder
xcodebuild clean -project Spotique.xcodeproj -scheme Spotique

# Build for a generic device
xcodebuild -project Spotique.xcodeproj -scheme Spotique -destination generic/platform=iOS build

# Open in Xcode
open Spotique.xcodeproj
```

If the `iPhone 16` simulator isn't installed, substitute an available device (`xcrun simctl list devices available`).

## Architecture

- **MVVM** — Views observe ViewModels (`@Observable`), ViewModels call services/repositories, models are plain structs or `@Model` classes.
- **SwiftUI + SwiftData** — SwiftData for local persistence with `@Model` classes and `ModelContainer`/`ModelContext`.
- **Entry point**: `SpotiqueApp.swift` — sets up the `ModelContainer` with the schema and injects it via `.modelContainer()`.
- **Data models**: Defined in `Spotique/` as `@Model` classes (currently `Item`).
- **Views**: SwiftUI views using `@Query` for reactive data fetching and `@Environment(\.modelContext)` for writes.
- **Tests**: Unit tests use Swift Testing framework (`import Testing`, `@Test`). UI tests use XCTest/XCUIApplication.

### Data Flow & Layers

`View → ViewModel → Service/Repository → SwiftData / REST API / Firestore`

- **Views** — UI rendering, user input capture, and bindings to ViewModel state only.
- **ViewModels** — business logic, state management, form validation, and computed properties that derive UI state.
- **Services/Repositories** — the data-access layer behind protocols (one per domain: listings, bookings, ratings, profile). ViewModels talk to these, never directly to SwiftData, Firestore, or `URLSession`.

### Project Structure

Organize by feature as the app grows:

- `Models/` — `@Model` classes and API/domain types
- `Services/` (or `Repos/`) — service and repository protocols and implementations
- `Features/` — SwiftUI views and ViewModels grouped by feature (Map, Listings, Bookings, Ratings, Profile, …)
- `Extensions/` — extensions of system types
- `Utilities/` — shared constants, helpers, network monitoring
- `SpotiqueTests/` — Swift Testing unit tests; `SpotiqueUITests/` — XCUITest

### When Adding a Feature

1. Create a ViewModel for any view with business logic (form validation, data operations, state management).
2. Keep views lightweight — rendering and user interaction only.
3. Put data access behind a service/repository protocol; inject it into the ViewModel.
4. Follow the ViewModel standards below.
5. Write unit tests for the ViewModel and its service/repository logic.
6. Model contracts come from [`../docs/api-contract.md`](../docs/api-contract.md) — don't invent request/response shapes.

### ViewModel Standards

- `@Observable` and `@MainActor` (see `mvvm-architecture`)
- Consistent error handling and loading state (prefer one `State` enum over scattered booleans)
- Computed properties for UI state derivation — keep them cheap
- Clear separation of business logic from UI logic

## Concurrency

- The project builds in Swift 6 language mode with `SWIFT_APPROACHABLE_CONCURRENCY = YES` and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so types are `@MainActor` by default and data races are compile errors. Keep the build at zero concurrency warnings.
- Types used off the main actor (API models, networking, parsers) must be explicitly `nonisolated` and `Sendable`. Use `@concurrent` for CPU-heavy work and an `actor` for shared background state.
- Follow the `swift-concurrency-6-2` skill for the rules on `@unchecked Sendable` (SwiftData models only) and `nonisolated(unsafe)` (documented, lock-protected only).

## Key Dependencies

- **Firebase Auth** — Phone-number SMS verification (the only auth method)
- **Cloud Firestore** — Remote data store for listings, bookings, ratings, user profiles
- **Google Maps SDK for iOS** — Map view and address autocomplete (scoped to Jackson Heights 11372)
- **APNs** — Push notifications for booking lifecycle events

## Conventions

- Use `async/await` for all asynchronous work; avoid Combine unless wrapping a delegate-based API.
- ViewModels should be `@Observable` classes with `@MainActor` when they drive UI state.
- Write unit tests for every ViewModel. Mock service dependencies with protocols.
- Follow Swift API Design Guidelines for naming.
- Keep views thin — no business logic in SwiftUI view bodies.

### Code Style

- Prefer `for … where` over a nested `if` when a loop body has a single condition:
  ```swift
  for item in items where item.isValid { process(item) }   // preferred
  ```
- Never force-unwrap (`!`, `try!`, `as!`) in app code; use `guard let` / `if let`. Force unwraps are acceptable only in tests and previews.
- **Code splitting**: when a file exceeds ~300 lines, split it into smaller focused files. When a function exceeds ~30 lines or does more than one thing, split it into purpose-driven functions.
- **Extensions**: extensions of system types (`String`, `Date`, SwiftUI types) live in `Extensions/` named `TypeName+Extensions.swift`. Extensions specific to an app model stay in the model's file (or a model-specific file). Test helpers stay in test files or test helper types.

### Logging

- Use `os.Logger` (with a subsystem and category) for logging; don't leave `print()` in app code.
- Never log tokens, verification codes, phone numbers, or full street addresses; mark interpolated personal data `.private`. See `ios-security-review`.

### Testing

- **Always run the tests after making code changes** to catch regressions, and add unit tests for new functionality and bug fixes.
- Every ViewModel gets unit tests; mock services with protocols. Types isolated to `@MainActor` need `await` when created or called from tests.
- Tests must be deterministic — no real network, no live Firebase/SMS, no `sleep`.

### Localization

- Keep all user-facing strings in the String Catalog (`Localizable.xcstrings`; create it when the first user-facing strings land) and verify that new or changed strings have entries before considering a task complete. See `swiftui-development` for the patterns.

### Performance Review

After the tests pass on a change that touches lists, the map, launch, images, or networking, review it with the `ios-performance` skill and address what it finds. Re-run the tests if you make optimizations.

## Skills

Use these skills (in [`../.claude/skills/`](../.claude/skills/)) for iOS work:

- `spotique-brand-ui` — colors, typography, spacing for any screen or component
- `liquid-glass-design` — iOS 26 Liquid Glass for navigation, toolbars, and floating map controls
- `swift-concurrency-6-2` — Swift 6.2 concurrency patterns (`@MainActor`, `@concurrent`, isolated conformances)
- `swift-actor-persistence` — actor-based file-backed caches (SwiftData remains the default for local persistence)
- `mvvm-architecture` — `@Observable` ViewModels, protocol-based DI, navigation, error handling
- `swiftui-development` — building views: composition, state, accessibility, previews
- `ios-api-client` — networking layer, Codable models from the API contract, auth, offline behavior
- `swift-code-review` — reviewing Swift/SwiftUI changes
- `ios-debugging` — diagnosing crashes, concurrency, memory, and SDK issues
- `ios-performance` — Instruments-driven profiling of launch, lists, map, and battery
- `ios-security-review` — Keychain, ATS, auth, and the address/phone privacy model
- `xcode-cloud` — CI/CD workflows, `ci_scripts`, secrets, TestFlight

## Shared API Contract

See [`../docs/api-contract.md`](../docs/api-contract.md) for the REST endpoints this client calls.
