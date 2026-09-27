# Feature: iOS Foundation (App Shell, Design System, Networking, Session, Test Infra)

> Validate documentation, codebase patterns, and task sanity before implementing. This plan defines the shared building blocks every other plan in `iOS/plans/` depends on — names and file paths here are the ones other plans reference.

**Source:** `docs/prd-v1.md` §7 (non-functional requirements), `docs/api-contract.md` (conventions, error format, auth header), `docs/specs/user-registration.md` (iOS section), `iOS/CLAUDE.md`, `iOS/plans/README.md`.

## Feature Description

Replace the Xcode template with the architectural skeleton of the Spotique app: a dependency-injected app shell with a root router that switches between signed-out, profile-incomplete, and main-app states; the brand design system; an `async/await` API client that speaks the Rails contract; Keychain-backed session storage; logging; a String Catalog; and test infrastructure (fakes and JSON fixtures). No product screens beyond placeholders.

## User Story

As a Spotique developer, I want a consistent app shell, networking layer, and design system, so that every feature plan can be built quickly, consistently, and testably.

## Problem Statement

`iOS/Spotique/` contains only the Xcode template (`Item` SwiftData model, list/detail `ContentView`). There is no networking, session handling, brand styling, navigation structure, or test scaffolding. Building features first would duplicate this work inconsistently.

## Solution Statement

Build the foundation once, following `iOS/CLAUDE.md` and the project skills: MVVM with `@Observable @MainActor` ViewModels, protocol-based services injected via an `AppEnvironment`, a single `APIClient` that owns base URL/auth header/decoding/error mapping, a `SessionStore` that owns the token and signed-in user, and an `AppRouter` that owns top-level navigation state. Delete the template.

## Requirements & Acceptance Criteria

From PRD §4.1 / §7 and the contract:

- Unauthenticated users cannot access any screen beyond the auth flow (PRD §4.1).
- App cold launch within 3 seconds on the minimum supported device (PRD §7.1).
- Authenticated requests send `Authorization: Bearer <token>`; errors use the contract format `{ "error": { code, message, details } }`.
- 403 `profile_incomplete` routes the user to profile completion; 401 clears the session and returns to sign-in.
- Minimum 44×44pt touch targets, Dynamic Type, ≥4.5:1 body-text contrast, no color-only state (PRD §7.3).
- No third-party analytics SDK (PRD §7.2).

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: High (foundational; many files, no user-visible UI)
**Platforms**: iOS
**Primary Systems Affected**: `iOS/Spotique/` (all), `iOS/SpotiqueTests/`, `iOS/Spotique/Assets.xcassets`
**Dependencies**: None external. (Google Maps/Places SDKs are added in plans 03 and 07.)

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING

- `iOS/Spotique/SpotiqueApp.swift` — template entry point with `ModelContainer(for: Item.self)`; replace.
- `iOS/Spotique/ContentView.swift`, `iOS/Spotique/Item.swift` — template; delete.
- `iOS/SpotiqueTests/SpotiqueTests.swift`, `iOS/SpotiqueUITests/*` — template tests; replace/keep the launch test.
- `iOS/Spotique.xcodeproj/project.pbxproj` — confirms: iOS 26.1 deployment target, `SWIFT_VERSION = 5.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and file-system-synchronized groups (new files under `iOS/Spotique/` and the test folders are auto-included; no pbxproj edits for source files).
- `iOS/Spotique/Assets.xcassets/AccentColor.colorset/Contents.json` — set to Deep Navy.
- `.claude/skills/spotique-brand-ui/SKILL.md` — brand colors/tokens/typography rules (lines ~18–60 tokens, ~140–146 iOS notes).

### New Files to Create

```
iOS/Spotique/App/SpotiqueApp.swift              (replaces template)
iOS/Spotique/App/AppEnvironment.swift           DI container of services
iOS/Spotique/App/AppRouter.swift                top-level navigation state
iOS/Spotique/App/RootView.swift                 switches on router state
iOS/Spotique/Core/Networking/APIConfiguration.swift
iOS/Spotique/Core/Networking/Endpoint.swift
iOS/Spotique/Core/Networking/APIClient.swift
iOS/Spotique/Core/Networking/APIError.swift
iOS/Spotique/Core/Networking/JSONCoding.swift
iOS/Spotique/Core/Auth/TokenStore.swift         Keychain wrapper (+ in-memory fake for tests)
iOS/Spotique/Core/Auth/SessionStore.swift
iOS/Spotique/Core/DesignSystem/Color+Brand.swift
iOS/Spotique/Core/DesignSystem/Typography.swift
iOS/Spotique/Core/DesignSystem/Components/{PrimaryButton,SecondaryButton,Card,StatusBadge,ErrorBanner,LoadingOverlay,EmptyStateView}.swift
iOS/Spotique/Core/Logging/Log.swift
iOS/Spotique/Core/Storage/ModelContainerFactory.swift
iOS/Spotique/Core/Extensions/{Date,Int,String,Calendar}+Extensions.swift   (Int: cents → currency string; Calendar.spotique / MarketTime.zone = America/New_York, the single market time zone used for availability and countdowns)
iOS/Spotique/Models/{User,Listing,Booking,Rating,Enums}.swift   (contract types, see below)
iOS/Spotique/Services/{AuthService,UserService}.swift            (protocols + Live impls; screens come in plan 02)
iOS/Spotique/Localizable.xcstrings
iOS/SpotiqueTests/Fakes/{FakeTokenStore,StubURLProtocol,FakeAuthService,FakeUserService}.swift
iOS/SpotiqueTests/Fixtures/*.json               (contract examples)
iOS/SpotiqueTests/{APIClientTests,SessionStoreTests,AppRouterTests,ModelDecodingTests}.swift
```

### Documentation — READ BEFORE IMPLEMENTING

- `docs/api-contract.md` — "Error Format", "Enums", user object shape in `POST /auth/verify`, pagination `meta`.
- Apple: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [URLSession async/await](https://developer.apple.com/documentation/foundation/urlsession), [Observation](https://developer.apple.com/documentation/observation), [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog).

### Skills to Apply

- `mvvm-architecture` — ViewModel/service/DI shape.
- `ios-api-client` — client design, error mapping, auth refresh policy, `URLProtocol` tests.
- `swiftui-development`, `spotique-brand-ui`, `liquid-glass-design` — components and tokens.
- `swift-concurrency-6-2` — default-MainActor implications; `nonisolated`/`Sendable` for models.
- `ios-security-review` — Keychain accessibility, no secrets in logs.

### Patterns to Follow

There is no existing app code to mirror. The patterns *defined here* are the canonical ones:

**ViewModel**: `@Observable @MainActor final class XViewModel`, single `State` enum where practical, dependencies injected as protocols via `init`.
**Service**: `protocol XServicing: Sendable { func … async throws -> … }` + `struct LiveXService: XServicing` that takes `APIClient`.
**Models**: `nonisolated struct Foo: Codable, Sendable, Identifiable, Hashable` (needed because default actor isolation is `MainActor`).
**Error**: throw `APIError`; ViewModels map to user-facing text using `LocalizedError.errorDescription`.
**Logging**: `Log.network`, `Log.auth`, … (`os.Logger`); interpolate personal data with `privacy: .private`; never log tokens/codes/phones/addresses.

---

## PRIVACY & SECURITY

- Token stored in the Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; never in `UserDefaults`, SwiftData, or logs.
- Auth header attached only for requests to the configured API host.
- ATS unmodified (HTTPS only; `localhost` HTTP allowed only in the Debug configuration via an xcconfig/Info.plist override, not globally).
- The `Listing`/`Booking` models represent hidden fields (`address`, `host_phone`, `driver_phone`, `payment_method_text`) as **optionals that are `nil` unless the API returned them**; the client never fabricates them.
- Sign-out clears Keychain token, in-memory user, and any SwiftData caches.

## IMPLEMENTATION PLAN

### Phase 1: Project cleanup & configuration
Remove the template; set the accent color; add the String Catalog; define API base-URL configuration per build configuration.

### Phase 2: Design system
Brand color tokens as asset-catalog colorsets, typography helpers, and the shared component set every screen uses.

### Phase 3: Networking & session
`APIClient`, `Endpoint`, `APIError`, JSON coding, `TokenStore`, `SessionStore`, model types, and the auth/user service protocols.

### Phase 4: App shell
`AppEnvironment`, `AppRouter`, `RootView` with placeholder destinations for signed-out / profile-incomplete / main tabs.

### Phase 5: Tests
Fixtures, fakes, and unit tests for the above.

---

## STEP-BY-STEP TASKS

Execute in order. Each task ends with a validation command (run from `iOS/`).

### REMOVE template files
- **IMPLEMENT**: Delete `Item.swift` and `ContentView.swift`; remove the `Item` schema use.
- **GOTCHA**: Do this together with the `SpotiqueApp.swift` rewrite so the project keeps compiling.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### UPDATE Assets.xcassets (brand colors + accent)
- **IMPLEMENT**: Add colorsets `BrandNavy #0D1F3C`, `BrandGold #C5943C`, `BrandIvory #F7F3EC`, `BrandCharcoal #2C2C2A` with dark-appearance variants (per `spotique-brand-ui`); set `AccentColor` to Deep Navy (do **not** use gold as the accent).
- **PATTERN**: `.claude/skills/spotique-brand-ui/SKILL.md` "Color Tokens" and iOS notes.
- **VALIDATE**: `xcodebuild … build` (generated `Color.brandNavy` symbols compile).

### CREATE Core/DesignSystem/Color+Brand.swift, Typography.swift
- **IMPLEMENT**: `Color` extension exposing semantic roles (`brandNavy`, `brandGold`, `brandIvory`, `brandCharcoal`, plus `surface`, `onSurface`, `success`, `warning`, `danger` derived from tokens). Typography uses semantic text styles only (`.title`, `.headline`, `.body`, `.caption`) with helpers for price/rate emphasis.
- **GOTCHA**: `List`/`Form` paint their own background — components apply `.scrollContentBackground(.hidden)` and `.background(Color.brandIvory)`.
- **VALIDATE**: build.

### CREATE Core/DesignSystem/Components/*
- **IMPLEMENT**: `PrimaryButton` (navy fill, ≥44pt, loading state), `SecondaryButton`, `Card`, `StatusBadge(status:)` (icon + text + color; statuses pending/confirmed/declined/cancelled/completed), `ErrorBanner(message:retry:)`, `LoadingOverlay`, `EmptyStateView(icon:title:message:action:)`. Each has `#Preview`s for normal, loading, disabled, large Dynamic Type, dark mode.
- **PATTERN**: `swiftui-development` (accessibility, previews); `liquid-glass-design` for any floating variants (deferred to feature plans).
- **GOTCHA**: `StatusBadge` must never convey status by color alone.
- **VALIDATE**: build.

### CREATE Core/Logging/Log.swift
- **IMPLEMENT**: `enum Log { static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network") … }` for `network`, `auth`, `ui`, `storage`.
- **VALIDATE**: build.

### CREATE Core/Networking/APIConfiguration.swift, JSONCoding.swift
- **IMPLEMENT**: `APIConfiguration { baseURL: URL }` with `.debug` (local Rails, e.g. `http://localhost:3000/api/v1` — Debug only), `.release` (production placeholder via build setting/Info.plist key `API_BASE_URL`). `JSONCoding` provides shared `decoder` (ISO 8601 with fractional seconds tolerance, `keyDecodingStrategy = .convertFromSnakeCase`) and `encoder` (`.convertToSnakeCase`).
- **GOTCHA**: `.convertFromSnakeCase` turns `rating_positive_pct` into `ratingPositivePct` — models must use those names, or define explicit `CodingKeys` where an acronym breaks (e.g. `hostId`).
- **VALIDATE**: `ModelDecodingTests` (later task).

### CREATE Core/Networking/APIError.swift
- **IMPLEMENT**: `nonisolated enum APIError: Error, Equatable, LocalizedError` with cases: `unauthorized`, `profileIncomplete`, `forbidden(code:)`, `notFound`, `validation(message:fields:[String:[String]])`, `conflict(code:message:)` (booking_conflict), `rateLimited`, `offline`, `server`, `decoding`, `unknown`. Parse the contract error body (`error.code/message/details`) and **keep the server `message` on `.unauthorized` and `.validation`** (the Rails auth endpoints return no `error.code`, so plan 02 distinguishes invalid vs. expired codes by status + message); map status 400/401/403/404/409/422/429/5xx and `URLError.notConnectedToInternet`/`.timedOut`. `errorDescription` returns localized, user-presentable text.
- **VALIDATE**: `APIClientTests`.

### CREATE Core/Networking/Endpoint.swift, APIClient.swift
- **IMPLEMENT**: `Endpoint` describes method, path, query items, JSON body, `requiresAuth`. `APIClient` (`Sendable`, uses an injected `URLSession`, `TokenProviding`, `APIConfiguration`) exposes `func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T` and a `sendEmpty` variant for 204s; unwraps the `{ "data": … }` envelope; exposes a `PagedResponse<T>` (`data`, `meta.pagination`). Attaches `Authorization: Bearer` only when `requiresAuth`. On 401 from an endpoint with `requiresAuth == true` calls the injected `onUnauthorized` handler (SessionStore signs out) and throws `.unauthorized` — the handler is **not** called for `requiresAuth == false` endpoints (e.g. `verify` returning 401 for a bad code) and an `Endpoint` can opt out explicitly (`handlesUnauthorized: false`); on 403 with code `profile_incomplete` throws `.profileIncomplete`.
- **PATTERN**: `ios-api-client` skill (Client Design, Error Handling). Requests cancel with the calling `Task`; 15 s request timeout; no automatic retry of non-idempotent requests.
- **GOTCHA**: Default actor isolation is MainActor — mark `APIClient`, `Endpoint`, and generic helpers `nonisolated` so decoding does not hop to the main actor.
- **VALIDATE**: `xcodebuild … test -only-testing:SpotiqueTests/APIClientTests`

### CREATE Core/Auth/TokenStore.swift
- **IMPLEMENT**: `protocol TokenStoring: Sendable { func token() -> String?; func save(_:) throws; func clear() }` and `KeychainTokenStore` (generic-password item, service = bundle ID, account `"auth-token"`, `AfterFirstUnlockThisDeviceOnly`).
- **VALIDATE**: `SessionStoreTests` uses `FakeTokenStore`; Keychain impl verified manually in the simulator (Keychain unit tests need a host app).

### CREATE Core/Auth/SessionStore.swift
- **IMPLEMENT**: `@Observable @MainActor final class SessionStore` with `state: SessionState` (`.launching`, `.signedOut`, `.needsProfile`, `.signedIn(User)`), `currentUser: User?`, and methods: `restore()` (read token; if present call `UserServicing.currentUser()`; 403 `profile_incomplete` → `.needsProfile`; 401 → `.signedOut`), `signIn(token:user:)`, `signInNeedingProfile(token:)`, `profileCompleted(user:)`, `update(user:)`, `signOut()` (clears token, user, caches). Additional requirements from plans 02/07/11: (a) a small Keychain-stored **session snapshot** (non-sensitive user fields + profile-complete flag, defined in plan 02) so a relaunch mid-profile or offline resumes without re-verifying; (b) a **sign-out cleanup registry** — `SessionStore.register(cleanup: @escaping @MainActor () async -> Void)` — run in registration order by `signOut()` *before* the token is cleared. Registered by: plan 11 (unregister the APNs device token, which needs the token), plan 07 (listing-draft store), plan 08/03 (`ListingCache`), plan 06 (`BookingCache`), plan 04 (`ImageDiskCache`).
- **PATTERN**: `mvvm-architecture`. State transitions only through these methods.
- **GOTCHA**: `GET /users/me` is **not in the contract** (see README gap 5). Until it exists, `restore()` treats a stored token as signed-in with a cached `User` snapshot (Keychain-adjacent, non-sensitive fields only) and relies on 401/403 handling for staleness. Record the chosen behavior in NOTES.
- **VALIDATE**: `SessionStoreTests` — all transitions, sign-out clears token, 401 handler signs out.

### CREATE Models/*
- **IMPLEMENT**: Contract-shaped, `nonisolated`, `Codable & Sendable & Hashable`:
  - `Enums.swift`: `UserRole (host, driver, both)`, `SpotType (driveway, garage)`, `BookingStatus (pending, confirmed, declined, completed, cancelled, unknown)`, `RatingScore (up = 1, down = -1)`, `DriverIssueTag`, `HostIssueTag` (raw values from the contract). Unknown-tolerant decoding for server-extensible enums.
  - `User`: `id, phone?, email?, firstName, lastName, address, role, ratingPositivePct, ratingCount, noShowCount, createdAt, paymentMethodText?`.
  - `Listing`: `id, hostId, hostDisplayName, hostRatingPositivePct, hostRatingCount, latitude, longitude, displayAddress, spotType, hourlyRateCents, description?, photos [URL], availabilitySchedule [Weekday: DaySchedule], blockedDates [String], paymentMethodText?, active, createdAt, address?` (**`address` optional; only present for confirmed bookings**).
  - `DaySchedule`: `enabled, start?, end?` ("HH:mm").
  - `Booking`: `id, listingId, driverId, hostId, status, startTime, endTime, totalCents, noShow, declineReason?, createdAt, address?, hostPhone?, driverPhone?, paymentMethodText?`. The contract's booking has **no counterpart names or listing `display_address`**, which the inbox/bookings rows need; plan 06 adds optional summary fields (`listing`, `host`, `driver` summaries with display name and street-level `display_address`) — treat them as optional until the API provides them (README gap 11).
  - `Rating`, `PublicRatingSummary (userId, positivePct, ratingCount, noShowCount)`.
- **PATTERN**: contract sections "Listings", "Bookings", "Ratings", "Enums".
- **GOTCHA**: `availability_schedule` keys are weekday names — decode into `[Weekday: DaySchedule]` with `Weekday` as `String`-raw `CodingKeyRepresentable`, or a `[String: DaySchedule]` wrapper. Test with the contract example where disabled days omit `start`/`end`.
- **VALIDATE**: `ModelDecodingTests` decoding fixtures copied verbatim from the contract.

### CREATE Services/AuthService.swift, UserService.swift (protocols + Live)
- **IMPLEMENT**: `AuthServicing`: `sendCode(_ destination: AuthDestination) -> SendCodeResult`, `verify(_ destination:, code:) -> VerifyResult`, `completeProfile(_ input:) -> User`. `UserServicing`: `currentUser() -> User` (needs endpoint — see gap), `update(_ fields:) -> User`, `deleteAccount()`. `Live*` implementations use `Endpoint`s. Screens are built in plan 02/13.
- **VALIDATE**: covered by plan 02 tests; here just build + a stubbed-`URLProtocol` decode test for `verify`.

### CREATE App/AppEnvironment.swift
- **IMPLEMENT**: `struct AppEnvironment` (or `@Observable final class`) holding `apiClient`, `sessionStore`, and every service protocol instance; factories `.live(configuration:)` and `.preview` (fakes). Injected with `.environment(...)` at the root. Later plans add their service here — **one alphabetically-ordered line each** (to minimize merge conflicts when plans run in parallel), plus one fake in `SpotiqueTests/Fakes/`. Known additions: `bookingCache` (06), `bookingService` (05), `deviceService` (11), `imageCache` (04), `listingService` (03), `placesService` (07), `ratingService` (12).
- **VALIDATE**: build.

### CREATE App/AppRouter.swift, RootView.swift, SpotiqueApp.swift
- **IMPLEMENT**: `SpotiqueApp` builds `AppEnvironment.live`, calls `sessionStore.restore()` in `.task`. `RootView` switches on `SessionState`: `.launching` → launch/loading view; `.signedOut` → `AuthFlowPlaceholder` (replaced by plan 02); `.needsProfile` → placeholder; `.signedIn` → `MainTabView` placeholder with tabs **Explore**, **Bookings**, **Listings** (hosts), **Profile** (final tab set finalized by plans 03/06/07/13; tab visibility depends on `user.role`). `AppRouter` (`@Observable @MainActor`) holds `selectedTab: AppTab` (`enum AppTab { explore, bookings, inbox, listings, profile }`; visibility by `user.role`: Explore/Bookings for driver/both, Inbox/Listings for host/both, Profile for all — host-only users skip Explore), `pendingDeepLink: DeepLink?` (`DeepLink` enum is **defined in plan 11**; plan 01 declares the property and a `consumeDeepLink()` stub), and `ratingSheet: RatingRoute?` (type defined in plan 12; presented from `MainTabView`).
- **PATTERN**: `swiftui-development` (`NavigationStack` per tab, typed paths).
- **GOTCHA**: Keep launch work minimal (no network before first frame) — PRD §7.1 cold launch ≤ 3 s. The SwiftData container is only created if a feature needs it (see Storage below).
- **VALIDATE**: `xcodebuild … build` and `AppRouterTests`.

### CREATE Core/Storage/ModelContainerFactory.swift
- **IMPLEMENT**: Factory that builds a `ModelContainer` for the cache schema (empty at this stage; plans 03/06 register `CachedListing`/`CachedBooking`). Provides an in-memory variant for tests/previews. Wire into `SpotiqueApp` with `.modelContainer(...)`. Cache models are registered by the plans that create them: `CachedListing` (plan 03) and `CachedBooking` (plan 06), each redacted of address/phone. The on-disk photo cache `Core/Storage/ImageDiskCache.swift` is created by plan 04.
- **PATTERN**: `swift-actor-persistence` Spotique Context (SwiftData default; never persist hidden address/phone).
- **VALIDATE**: build.

### CREATE Localizable.xcstrings
- **IMPLEMENT**: Create the String Catalog with the strings introduced in this plan; enable "Use Compiler to Extract Swift Strings" so new SwiftUI literals are captured.
- **VALIDATE**: build; open the catalog and confirm no "stale" foundation strings.

### CREATE test fakes and fixtures
- **IMPLEMENT**: `StubURLProtocol` (queue of canned responses), `FakeTokenStore`, `FakeAuthService`, `FakeUserService`; JSON fixtures: `user.json`, `verify-existing.json`, `verify-new.json`, `listing.json`, `booking-pending.json`, `booking-confirmed.json`, `error-validation.json`, `error-conflict.json`.
- **VALIDATE**: `xcodebuild … test`.

### CREATE foundation tests
- **IMPLEMENT**: `APIClientTests` (envelope unwrap; auth header on/off; 401 → handler + `.unauthorized`; 403 `profile_incomplete`; 409 `booking_conflict`; 422 field errors; 429; offline; malformed JSON → `.decoding`; cancellation). `SessionStoreTests` (restore with/without token; sign-in/out; profile transitions; sign-out clears token). `AppRouterTests`. `ModelDecodingTests` (fixtures; optional hidden fields absent → nil; unknown enum value tolerated).
- **PATTERN**: `import Testing`, `@Test`, `#expect`; `@MainActor` types created with `await`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`

### UPDATE iOS/CLAUDE.md and iOS/README.md
- **IMPLEMENT**: Update the architecture/data-model lines (template `Item` is gone); replace the Firebase dependency lines per the decision on README gap 1; document the layout and the "add a service to `AppEnvironment`" step.
- **VALIDATE**: read-through.

---

## TESTING STRATEGY

### Unit Tests
As listed above; all deterministic with `StubURLProtocol` and fakes; Swift Testing.

### Integration / UI Tests
Keep `SpotiqueUITests` launch test; add a UI test asserting an unauthenticated launch shows the auth placeholder (expanded in plan 02).

### Edge Cases
Token present but server returns 401 on first call; 403 `profile_incomplete` at restore; no network at launch (must not block first frame; show signed-in shell from cached snapshot or sign-in); malformed error body; extremely large `per_page`; clock/timezone differences in date decoding; Dynamic Type XXL on components; dark mode contrast.

## VALIDATION COMMANDS (from `iOS/`)

### Level 1: Build
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### Level 2: Unit tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`

### Level 3: Manual
Launch in the simulator: signed-out state shows the placeholder; components previews render in light/dark and XXL text; Keychain token survives relaunch (after a temporary debug sign-in).

## OPEN QUESTIONS

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | REST + JWT only (no Firebase SDK)? Update `iOS/CLAUDE.md` accordingly. | README gap 1 | Pending |
| 2 | Token lifetime / refresh behavior (currently no `exp`). | Security review | Pending |
| 3 | `GET /users/me` for session restore. | README gap 5 | Pending |
| 4 | API base URLs per environment (local/staging/prod). | Discovered | Pending |
| 5 | Is Dark Mode in scope for MVP, or light-only? (Brand skill defines dark variants.) | Discovered | Pending |

## ACCEPTANCE CRITERIA

- [ ] Template code removed; app launches to a signed-out placeholder
- [ ] Brand tokens and components exist with previews (light/dark/XXL)
- [ ] `APIClient` maps every contract error class and unwraps envelopes; covered by tests
- [ ] Token stored only in Keychain; sign-out clears token/user/caches
- [ ] `SessionStore` state machine and `AppRouter` covered by tests
- [ ] All contract models decode fixtures; hidden fields are optional
- [ ] `AppEnvironment` provides live and preview/fake configurations
- [ ] String Catalog exists; no user-facing string bypasses it
- [ ] All validation commands pass; no new warnings
- [ ] Privacy model upheld; no secrets or PII in logs

## COMPLETION CHECKLIST

- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] `iOS/CLAUDE.md` / `iOS/README.md` updated
- [ ] Open questions recorded with decisions

## NOTES

- **Default MainActor isolation** is the main gotcha in this project: any type used from `nonisolated` contexts (models, `APIClient`, `Endpoint`) must be explicitly `nonisolated`.
- Project uses **Swift 5 mode** with approachable concurrency; do not flip to Swift 6 as part of this plan.
- Every later plan registers its service by adding one property to `AppEnvironment` and one fake to `SpotiqueTests/Fakes/`.
- **Cross-plan additions to this plan** (from the parallel plan authors): `SessionStore` snapshot + async sign-out cleanup registry; `AppTab`, `DeepLink`, and `ratingSheet` on `AppRouter`; `Calendar.spotique`; optional `Booking` summary fields; cache models registered per plan. These are already reflected in the tasks above.
- Xcode project defaults to iPad + landscape (`TARGETED_DEVICE_FAMILY = 1,2`) — plan 14 decides whether to restrict to iPhone/portrait for MVP.
