# iOS Implementation Plans

Implementation plans for the Spotique iOS app, derived from [`docs/prd-v1.md`](../../docs/prd-v1.md) (PRD v1.0, MVP) and grounded in [`docs/api-contract.md`](../../docs/api-contract.md) and the current state of `iOS/`. Each plan is written in the `plan-feature` format and is executable with the `execute-plan` skill.

**Status of the app today:** `iOS/Spotique/` is the untouched Xcode template (`SpotiqueApp.swift`, `ContentView.swift`, `Item.swift`). Everything below is greenfield.

## Plans

Build in dependency order. Plans in the same phase can be worked in parallel once their dependencies are done.

| # | Plan | PRD | Priority | Depends on |
|---|------|-----|----------|------------|
| 01 | [Foundation](01-foundation.md) — app shell, design system, networking, session, DI, test infra | §7 | P0 | — |
| 02 | [Auth & Onboarding](02-auth-onboarding.md) — send code, verify, complete profile, session gating | §4.1 | P0 | 01 |
| 03 | [Map & Discovery](03-map-discovery.md) — Google Maps, pins, "When" and type filters, preview card | §4.4 | P0 | 01, 02 |
| 04 | [Spot Detail](04-spot-detail.md) — gallery, host trust, availability, redacted address | §4.4 | P0 | 03 |
| 05 | [Request Booking](05-request-booking.md) — time selection, total, conflict handling, submit | §4.4 | P0 | 04 |
| 06 | [Driver Bookings](06-driver-bookings.md) — My Bookings, status badges, confirmed reveal, countdown | §4.5 | P0 | 05 |
| 07 | [Host: Create Listing](07-host-listing-creation.md) — wizard, Places autocomplete, photos, schedule | §4.2 | P0 | 01, 02 |
| 08 | [Host: Manage Listing](08-host-listing-management.md) — active toggle, edit, blocked dates, delete | §4.2 | P0 | 07 |
| 09 | [Host: Booking Inbox](09-host-booking-inbox.md) — pending requests, accept/decline, driver phone | §4.3 | P0 | 06, 07 |
| 10 | [Booking History](10-booking-history.md) — filter tabs, booking detail for all users | §4.3, §4.8 | P1 | 06, 09 |
| 11 | [Push Notifications](11-push-notifications.md) — permission, token registration, deep links, preferences | §4.7 | P0 (+P1) | 02, 06, 09 |
| 12 | [Ratings & No-Show](12-ratings-and-no-show.md) — rating flow, public stats, no-show reporting | §4.6 | P1 | 06, 09, 11 |
| 13 | [Profile & Settings](13-profile-and-settings.md) — profile, role toggle, settings, delete account | §4.8 | P1 | 02, 10 |
| 14 | [Hardening](14-hardening.md) — accessibility, offline, performance, privacy manifest, release readiness | §7 | P0 | all |

```
Phase 0  01 Foundation
Phase 1  02 Auth & Onboarding
Phase 2  Driver track:  03 → 04 → 05 → 06        Host track:  07 → 08 → 09
Phase 3  10 History · 11 Push · 12 Ratings · 13 Profile
Phase 4  14 Hardening
```

The driver and host tracks are independent after Phase 1 and can run in parallel. **API first, then client** applies per feature (see `.claude/agents.md`): today only the three `/auth/*` endpoints exist in `Api/`, so each plan lists the endpoints it needs and the client can be built against fakes/fixtures until the endpoint lands.

## Shared Conventions (all plans follow these)

Defined once in [01-foundation](01-foundation.md); other plans reference them instead of repeating them.

**Architecture** — MVVM: `View → ViewModel (@Observable @MainActor) → Service protocol → APIClient`. ViewModels never touch `URLSession`, SwiftData, or Keychain directly. See `.claude/skills/mvvm-architecture`.

**Layout** (inside `iOS/Spotique/`; the project uses file-system-synchronized groups, so new files are picked up automatically):

```
App/              SpotiqueApp, AppEnvironment (DI), RootView, AppRouter
Core/
  Networking/     APIClient, Endpoint, APIError, APIConfiguration
  Auth/           SessionStore, TokenStore (Keychain)
  DesignSystem/   Color+Brand, Typography, components (buttons, cards, badges)
  Storage/        SwiftData cache models, image cache
  Logging/        Log (os.Logger wrappers)
  Extensions/     TypeName+Extensions.swift
Models/           API models (User, Listing, Booking, Rating, enums)
Services/         XService protocol + LiveXService (Auth, Listing, Booking, Rating, User, Device, Places)
Features/<Name>/  <Name>View, <Name>ViewModel, subviews
SpotiqueTests/    Fakes/, Fixtures/ (JSON copied from the contract), <Feature>Tests
```

**Naming** — Feature views/ViewModels: `MapView`/`MapViewModel`. Services: `ListingServicing` (protocol) + `LiveListingService`; test double `FakeListingService`. API models mirror the contract names: `User`, `Listing`, `Booking`, `Rating`.

**Money and time** — money is `Int` cents end to end (`hourly_rate_cents`, `total_cents`); format with `Decimal`/`FormatStyle.Currency` for display only. Timestamps are ISO 8601 UTC; availability `start`/`end` are `"HH:mm"` strings interpreted in `America/New_York` (single-market MVP).

**Concurrency** — the project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` (Swift 5 mode). Everything is `@MainActor` by default, so API models and network code that must run off the main actor are marked `nonisolated` and `Sendable`. See `.claude/skills/swift-concurrency-6-2`.

**UI** — Spotique brand tokens only (`Color.brandNavy`, etc., defined in 01); `liquid-glass-design` for floating controls and toolbars; minimum 44×44pt targets; Dynamic Type; never convey state by color alone. See `.claude/skills/spotique-brand-ui`, `swiftui-development`.

**Privacy model (applies to every plan)** — the full street address and host phone are never requested, held, cached, logged, or displayed before a booking is `confirmed`. The client renders only what the API returns and never derives a full address from coordinates. Driver phone reaches the host at booking creation. See `.claude/skills/ios-security-review`.

**Testing** — Swift Testing for ViewModels and services (`import Testing`), fakes behind protocols, JSON fixtures copied from the contract, no live network. Run: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test` from `iOS/`.

**Strings** — all user-facing strings in `Localizable.xcstrings` (created in 01).

## Decisions and Gaps to Resolve

These surfaced while planning. Each plan repeats the ones that block it in its own **Open Questions** table.

### Contract / architecture

1. **Firebase vs. REST.** `iOS/CLAUDE.md` and the PRD list Firebase Auth, Firestore, and FCM; the contract and the Rails code use REST + a Rails-issued JWT (`POST /auth/send-code` → `verify` → `complete-profile`). The plans assume **REST + JWT only** (no Firebase SDK) and treat the Firebase lines in `iOS/CLAUDE.md` as stale. Confirm, then update `iOS/CLAUDE.md`.
2. **Token lifetime and refresh.** The API currently issues JWTs with no `exp` (flagged by the security review). Plan 01 handles a 401 by clearing the session and returning to sign-in; if the API adds `exp` and no refresh endpoint, users re-verify by code on expiry. Confirm the lifetime.
3. **No device-token endpoint.** Push (plan 11) needs a way to register the APNs token (e.g. `POST /devices`). Not in the contract.
4. **No "my listings" endpoint.** `GET /listings` requires `lat`/`lng` and returns other hosts' listings; hosts need their own (plans 07–08, 13). Suggest `GET /listings?mine=true` or `GET /users/me/listings`.
5. **No `GET /bookings/:id`, no `GET /users/me`.** Needed for deep links from notifications (plans 09, 11) and cold-start session restore (plan 02).
6. **Photo upload.** The contract says `photos: ["<upload_url_or_base64>"]`. The plans assume a direct multipart or presigned upload returning URLs; needs a decision (plan 07).
7. **Rating state on bookings.** Bookings don't say whether the caller has already rated, or whether the window is open (plan 12).
8. **"Driver arrived".** PRD §4.6 references marking a driver as arrived, but no endpoint or UI exists for it (plan 12).
9. **Notification preferences** (PRD §4.8) have no API (plans 11, 13).
10. **Contract text still mentions "Firebase ID token"** in the error table (401 row), and Firestore in `DELETE /users/me`; align with the REST/JWT design.
11. **Booking summaries.** `Booking` has no counterpart display names or listing `display_address`; bookings/inbox rows need them (embed `listing`/`host`/`driver` summaries).
12. **Coordinates leak the address.** `GET /listings` returns exact `latitude`/`longitude` to drivers, defeating the "street name only" rule (PRD §7.2). Recommend server-side fuzzing (~100 m) for unconfirmed viewers.
13. **`payment_method_text` is returned by `GET /listings` before confirmation**, but PRD §4.5 reveals it only after confirmation.
14. **Availability / conflicts.** No endpoint exposes a listing's booked intervals; the client can't pre-check conflicts (server 409 is authoritative). `POST /bookings` should also validate the weekly schedule and `blocked_dates`, and accept an idempotency key.
15. **Status semantics.** PRD says decline → "cancelled"; the contract uses `declined`. Nothing transitions `confirmed → completed`. `GET /bookings` has no documented ordering; the invalid-transition error code is unspecified.
16. **Driver phone timing** conflicts across PRD §4.3, §7.2 and the contract (creation vs. accept); `POST /bookings` returns none.
17. **Rating/no-show support.** No duplicate-rating error code, no suspended-driver (5 no-shows) error code, no "driver arrived" endpoint, and the rating push is sent at the same moment the window closes (48 h after end).
18. **Push payloads** must not include the full address (the contract says the confirm push includes it — contradicts the privacy model).
19. **Listings support gaps.** No duplicate-address warning field (assumed `meta.warnings`), no per-listing booking counts (delete warning), and blocked-dates edit semantics are unspecified.
20. **Auth error codes.** Rails auth endpoints return no `error.code`, so invalid vs. expired codes are distinguishable only by message text; the verify response omits `data.id` shown in the contract.

### Backend findings discovered while planning (Api/)

- `POST /auth/complete-profile` reads `current_user.address`/`user.address`, but the `users` table has no `address` column (addresses live in the `addresses` table), so the endpoint appears broken as written — verify on the API side.
- `PATCH /users/me` and `DELETE /users/me` are not in the Rails routes; JWTs carry no `exp` (flagged by the security review).

### Product / platform decisions surfaced

- **Brand Gold on Ivory is ~2.5:1 contrast** — fails PRD §7.3; use gold for decoration only, never text (plan 14).
- **No UGC report/block flow and no App Review demo login** are planned (App Review guideline 1.2 / 2.1); plan 14 flags them.
- The Xcode project targets iPhone + iPad and landscape; PRD says iPhone 12 or newer (iOS 26.1 supports iPhone 11+). Decide the supported device/orientation set (plan 14).

### PRD open questions that affect iOS (§8)

| # | Question | Affects |
|---|----------|---------|
| 1 | Host profile photo required? | 02, 13 |
| 2 | Auto-decline after 24h with no host response? | 06, 09 |
| 3 | Multi-day bookings? | 05 |
| 4 | More than one active listing per host? | 07, 08 |
| 5 | Grace period for driver cancellation? | 06, 12 |

The plans assume the simplest answer to each (no profile photo, no auto-decline UI, single-day bookings, multiple listings allowed, no driver cancel) and mark the assumption.
