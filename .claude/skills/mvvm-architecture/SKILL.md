---
name: mvvm-architecture
description: Design or review Spotique iOS architecture — MVVM with @Observable ViewModels, protocol-based dependency injection, navigation, and testable state management.
---

# Skill: MVVM Architecture (Spotique iOS)

Use when adding a feature's ViewModel/service layer, refactoring a view that has grown business logic, or reviewing data flow. Baseline conventions live in `iOS/CLAUDE.md`; this skill goes deeper.

## Before You Start

1. Read `iOS/CLAUDE.md` and the existing code in `iOS/Spotique/` to match current patterns.
2. Read the relevant endpoints in `docs/api-contract.md` — derive models from the contract, never invent shapes.

## Rules

- **Models** — plain `Codable`/`Sendable` structs matching the API contract; `@Model` classes only for SwiftData-persisted data.
- **ViewModels** — `@Observable` + `@MainActor` classes. They own screen state, validation, and calls to services. No `import SwiftUI` types beyond what's needed for state (no `View`, `Color`).
- **Views** — declarative and thin. Read state from the ViewModel, forward user intent as method calls. No business logic in `body`.
- **Services/repositories** — behind a protocol (`BookingServicing`, `ListingServicing`, …), `Sendable`, `async throws`. One responsibility each (networking, Firestore, persistence).
- **No Combine.** Use `async/await`; `@Observable` replaces `ObservableObject`/`@Published`. Combine only when wrapping a delegate-based API.
- **State ownership** — `@State` for a view owning its ViewModel (`@State private var viewModel = …`), `@Bindable` when you need bindings into an injected `@Observable`, `@Environment` for app-wide dependencies.

## ViewModel Shape

```swift
@Observable @MainActor
final class BookingRequestViewModel {
    enum State { case idle, submitting, submitted, failed(BookingError) }

    private(set) var state: State = .idle
    var startTime: Date = .now
    var endTime: Date = .now.addingTimeInterval(3600)

    private let service: any BookingServicing

    init(service: any BookingServicing) { self.service = service }

    func submit(listingID: String) async {
        state = .submitting
        do {
            try await service.requestBooking(listingID: listingID, start: startTime, end: endTime)
            state = .submitted
        } catch let error as BookingError {
            state = .failed(error)
        } catch {
            state = .failed(.unknown)
        }
    }
}
```

Prefer a single `State` enum over several loosely-related booleans (`isLoading`, `hasError`, …).

## Dependency Injection

- Inject protocols through `init` with a production default only at the composition root (`SpotiqueApp.swift` or a feature's entry view).
- Tests pass hand-written fakes conforming to the protocol. Keep fakes `Sendable`.
- Avoid singletons and service locators.

## Navigation

- Use `NavigationStack` with a typed path (`NavigationPath` or an enum route) owned by a ViewModel or a small router object, so deep links (e.g. from a push about a booking) can drive it.
- Present sheets/alerts from ViewModel state, not from ad-hoc view booleans.

## Error Handling

- Define feature-scoped `Error` enums with `LocalizedError` messages suitable for display.
- Map transport errors (HTTP status, Firestore, network) to domain errors inside the service, not in the view.
- ViewModels expose an error state; views render it.

## Testing

- Every ViewModel gets unit tests with Swift Testing (`import Testing`, `@Test`, `#expect`).
- Cover: initial state, success path, each failure mapping, and loading-state transitions.
- Test async methods with `await`; no `sleep`s.

## Review Checklist

- [ ] View bodies contain no business logic or networking
- [ ] ViewModel is `@Observable` and `@MainActor`, dependencies are protocols
- [ ] No Combine, no `ObservableObject`
- [ ] Models match `docs/api-contract.md`
- [ ] Errors mapped to domain errors; UI shows an error state
- [ ] ViewModel tests exist and cover failure paths
- [ ] Privacy model respected: full address and host phone are only held in state after booking confirmation
