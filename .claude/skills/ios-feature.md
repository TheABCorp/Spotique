# Skill: iOS Feature

Build a feature for the Spotique iOS app.

## Before You Start

1. Read `iOS/CLAUDE.md` for build commands, architecture, and conventions.
2. Read `docs/api-contract.md` for the endpoint this feature calls.
3. Understand the existing code structure in `iOS/Spotique/`.
4. Use the `spotique-brand-ui` skill for any screen or component work — colors, typography, spacing, and shape must follow it.

## Architecture

- **MVVM**: View (SwiftUI) → ViewModel (`@Observable`, `@MainActor`) → Service/Repository → Firestore/API.
- **SwiftUI + SwiftData** for UI and local persistence.
- **async/await** for all asynchronous work. No Combine unless wrapping delegates.

## Implementation Steps

1. **Define the model** — Create or update a struct/class in the models directory. Match field names to `docs/api-contract.md`.
2. **Create the service** — Protocol-based service that calls the API or Firestore. Use `async throws`.
3. **Create the ViewModel** — `@Observable class`, `@MainActor`. Expose published state. Call service methods. Handle loading/error states.
4. **Build the View** — SwiftUI view that observes the ViewModel. Keep the body thin — no business logic.
5. **Write tests** — Unit test the ViewModel with a mock service (protocol conformance). Test happy path, error, and edge cases.

## Key Dependencies

- **Firebase Auth** — Phone-number verification. Access the current user via `Auth.auth().currentUser`.
- **Cloud Firestore** — `import FirebaseFirestore`. Use codable mapping.
- **Google Maps SDK** — Map views and address autocomplete. Scope to Jackson Heights 11372.

## Constraints

- MVP geography: Jackson Heights, Queens, NY (zip 11372).
- Privacy: Never show full address or host phone until booking is confirmed.
- Auth: Phone-number only. Always check `Auth.auth().currentUser` before protected actions.
- Payments: Off-platform (cash/Venmo/Zelle). No payment UI needed.

## Naming Conventions

- Types: `UpperCamelCase` (e.g., `ListingViewModel`, `BookingService`)
- Properties/methods: `lowerCamelCase`
- Protocols for services: `ListingServiceProtocol`
- Test classes: `ListingViewModelTests`
