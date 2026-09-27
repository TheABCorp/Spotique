---
name: ios-api-client
description: Build the Spotique iOS networking layer — Codable models from docs/api-contract.md, async/await URLSession client, auth, error mapping, and offline/caching strategy.
argument-hint: "[endpoint-or-feature]"
---

# Skill: iOS API Client (Spotique)

Use when implementing or changing how the iOS app talks to the Rails API. The contract is the source of truth; the client conforms to it, not the reverse. (If the contract is wrong or missing something, flag it and update `docs/api-contract.md` — don't work around it in the client.)

## Before You Start

1. Read the endpoint(s) in `docs/api-contract.md`: paths, request/response shapes, validations, error format.
2. Look at the existing client code in `iOS/Spotique/` and extend it rather than creating a parallel stack.

## Models

- One `Codable`, `Sendable` struct per response/request shape, named after the contract.
- Use a shared `JSONDecoder`/`JSONEncoder` configured once: ISO 8601 dates, `.convertFromSnakeCase` (or explicit `CodingKeys` where the contract deviates).
- Model closed sets as `enum … : String, Codable` (e.g. booking status). Add an `unknown` fallback case where the server may add values, so decoding doesn't fail on new statuses.
- Optional only where the contract says nullable. Fields hidden before booking confirmation (full address, host phone) are optional and must not be assumed present.

## Client Design

```swift
protocol BookingServicing: Sendable {
    func requestBooking(listingID: String, start: Date, end: Date) async throws -> Booking
}
```

- Services are protocols; the production implementation wraps a small `APIClient` (built on `URLSession`, `async/await`) that handles base URL, auth header, encoding/decoding, and error mapping.
- Base URL and environment come from build configuration, not literals.
- Requests are cancellable (`Task` cancellation propagates) and use sensible timeouts.
- No Combine; no third-party networking library unless discussed.

## Authentication

- Auth is Firebase phone-number (SMS) verification. Attach the current user's ID token as the bearer token, refreshing via the Firebase SDK before it expires; retry once on 401 after a forced refresh, then sign the user out.
- Store nothing sensitive in `UserDefaults`; use the Keychain for anything persisted.

## Error Handling

- Map HTTP status + the contract's error body to a domain `APIError` (`unauthorized`, `validation([FieldError])`, `notFound`, `conflict`, `rateLimited`, `server`, `offline`, `decoding`).
- Conform to `LocalizedError` with user-presentable messages; surface validation errors per field.
- Retry only idempotent requests, with exponential backoff and jitter; never blindly retry a booking `POST`.

## Offline & Caching

- Browsing (map/listings) should degrade gracefully offline: show last-known listings from a cache and a clear offline banner.
- Cache with SwiftData or a file-backed actor (`swift-actor-persistence`). Use HTTP caching (`ETag`/`If-None-Match`) where the API supports it.
- Booking actions require connectivity — fail fast with a clear message instead of silently queuing.
- Cache only data the pre-booking UI may show; never persist full address or host phone for unconfirmed bookings.

## Testing

- Unit-test the client with a `URLProtocol` stub: success, each error status, malformed JSON, timeout/offline, 401-refresh-retry.
- Decode fixture JSON copied from the contract examples to catch drift.
- ViewModels are tested against fake services (see `mvvm-architecture`).

## Checklist

- [ ] Models and error handling match `docs/api-contract.md`
- [ ] `async/await`, protocol-based, injectable
- [ ] Auth token attached and refreshed correctly; no secrets in logs
- [ ] Domain errors with user-facing messages
- [ ] Offline behavior defined; nothing sensitive cached
- [ ] Tests with stubbed `URLProtocol` and fixtures
