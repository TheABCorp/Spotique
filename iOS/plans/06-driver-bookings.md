# Feature: iOS Driver Bookings (My Bookings, Status Badges, Confirmed Reveal, Countdown)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities (plan 01 defines `APIClient`, `Endpoint`, `PagedResponse`, `Booking`, `StatusBadge`, `EmptyStateView`, `ErrorBanner`, `AppEnvironment`, `AppRouter`; plan 05 defines `BookingServicing`), and import from the right files.

**Source:** `docs/prd-v1.md` §4.5 "P0 — Booking Status & Contact" (with §4.3, §4.7, §7.2, §7.3, §7.4, §8 open questions #2 and #5); `docs/api-contract.md` "Bookings" (`GET /bookings`, `PATCH /bookings/:id` confirm payload), "Enums", "Error Format"; `iOS/plans/README.md`; `iOS/plans/01-foundation.md`.

## Feature Description

The driver's **My Bookings** tab: a paginated, pull-to-refresh list of the driver's bookings with status badges (Pending / Confirmed / Declined / Cancelled / Completed), and a booking detail screen. When a booking is `confirmed` and the API returned them, the detail reveals the full street address, host phone (tap to call / copy) and payment-method text, plus a live "Your booking starts in X hours" countdown. This plan also creates the **role-agnostic** building blocks (`BookingRowView`, `BookingDetailView`/`BookingDetailViewModel`, `BookingsListViewModel`, `BookingCache`) that plans 09 (host inbox), 10 (history), 11 (deep links) and 12 (ratings/no-show hooks) reuse.

## User Story

As a driver / I want to see the status of every booking I requested and, once confirmed, the exact address, the host's phone number and how to pay / So that I can coordinate arrival and park without back-and-forth.

## Problem Statement

After submitting a request (plan 05) the driver has nowhere to track it. The address and host phone are intentionally hidden until confirmation, so the confirmed state must be a deliberate, safe reveal: shown only when the server says so, refreshed when status changes, and never persisted.

## Solution Statement

`BookingsListViewModel` (parameterised by `BookingRole` and a client-side `BookingListFilter`) loads pages from `GET /bookings?role=driver`, merges/dedups them, writes a **redacted** copy to a SwiftData cache and falls back to it offline. `BookingDetailViewModel` shows the list item immediately, then refreshes from `GET /bookings/:id` (not in the contract — falls back to scanning the list endpoint) and replaces the whole `Booking` value on every refresh, so hidden fields disappear automatically if the status changes. A pure `BookingCountdown` function (injected `now`) drives a `TimelineView` for the countdown. Contact reveal is a computed property gated on `status == .confirmed`; values are read from the API model only, never derived.

## Requirements & Acceptance Criteria

Verbatim from PRD §4.5:

- "My Bookings" list shows all driver bookings with status badges: Pending / Confirmed / Cancelled / Completed
- After confirmation: full address revealed, host phone number shown, payment method shown
- Push notification sent on host accept or decline (client side: plan 11; this plan must refresh on it)
- Address and host contact only visible to driver after status = confirmed
- Confirmed bookings show countdown: "Your booking starts in X hours"

Contract details used:

- `GET /bookings?role=driver&status=&page=&per_page=` → `{ data: [Booking], meta: { pagination: { page, per_page, total } } }`. "Confirmed bookings include `address`, `host_phone`/`driver_phone`, and `payment_method_text`. Other statuses redact those fields."
- `booking.status` ∈ `pending | confirmed | declined | completed | cancelled`; `decline_reason` is free text "shown to the driver" (PRD §4.3).
- PRD §7.4: "user's own bookings are shown from cache when offline". PRD §7.3: no color-only state, 44pt targets.

Derived (this plan):

- `declined` is shown as its own **Declined** badge (icon `xmark.circle` + text) with the host's reason, grouped with Cancelled in filters (PRD §4.3 says decline makes the booking "cancelled"; contract says `declined` — see Open Questions).
- No driver-side cancel UI and no auto-decline UI (PRD §8 #5, #2 assumed "not in MVP").

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium-High (shared components, cache, privacy rules, countdown)
**Platforms**: iOS (Api: `GET /bookings` must exist; `GET /bookings/:id` and embedded listing/host summary are gaps)
**Primary Systems Affected**: `iOS/Spotique/Features/Bookings/`, `Services/BookingService.swift`, `Models/Booking.swift`, `Core/Storage/`, `App/AppEnvironment.swift`, main tab view
**Dependencies**: SwiftData (cache), SwiftUI `TimelineView`; no third-party libraries.

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING

(All are planned paths from plan 01/05; verify they exist and match names before coding.)

- `iOS/Spotique/Models/Booking.swift`, `Models/Enums.swift` (`BookingStatus` incl. `.unknown`) — model with optional hidden fields; this plan adds summary fields.
- `iOS/Spotique/Services/BookingService.swift` (plan 05) — `BookingServicing` + `LiveBookingService`; extended here.
- `iOS/Spotique/Core/Networking/{APIClient,Endpoint,APIError}.swift`, `PagedResponse<T>` — `send`, error mapping (`.notFound`, `.offline`, `.unauthorized`).
- `iOS/Spotique/Core/DesignSystem/Components/{StatusBadge,Card,EmptyStateView,ErrorBanner,LoadingOverlay}.swift`.
- `iOS/Spotique/Core/Storage/ModelContainerFactory.swift` — register `CachedBooking`; in-memory variant for tests.
- `iOS/Spotique/App/{AppEnvironment,AppRouter,RootView}.swift` and the main tab view — Bookings tab placeholder to replace.
- `iOS/SpotiqueTests/Fakes/{StubURLProtocol,FakeBookingService}.swift`, `Fixtures/booking-pending.json`, `booking-confirmed.json`.

### New Files to Create

```
iOS/Spotique/Features/Bookings/MyBookingsView.swift            driver tab root (NavigationStack)
iOS/Spotique/Features/Bookings/BookingsRoute.swift             enum BookingsRoute: Hashable { case detail(bookingID: String) }
iOS/Spotique/Features/Bookings/BookingsListViewModel.swift     role + filter aware list state machine
iOS/Spotique/Features/Bookings/BookingListFilter.swift         client-side predicate (.all here; plan 10 adds more)
iOS/Spotique/Features/Bookings/BookingRowView.swift            role-agnostic row
iOS/Spotique/Features/Bookings/BookingDetailView.swift         generic over an `Extra` section builder
iOS/Spotique/Features/Bookings/BookingDetailViewModel.swift
iOS/Spotique/Features/Bookings/BookingContactSection.swift     revealed address / phone / payment
iOS/Spotique/Features/Bookings/BookingCountdown.swift          pure logic (phase + formatting input)
iOS/Spotique/Features/Bookings/BookingCountdownView.swift      TimelineView wrapper
iOS/Spotique/Features/Bookings/BookingPresentation.swift       status -> label/icon/a11y text
iOS/Spotique/Features/Bookings/BookingFormatting.swift         date range/day/total formatting in market time zone
iOS/Spotique/Core/Storage/CachedBooking.swift                  @Model, non-sensitive fields only
iOS/Spotique/Services/BookingCache.swift                       BookingCaching protocol + SwiftDataBookingCache (@ModelActor)
iOS/SpotiqueTests/Fakes/FakeBookingCache.swift
iOS/SpotiqueTests/Fixtures/{booking-declined,booking-cancelled,bookings-page1,bookings-page2}.json
iOS/SpotiqueTests/{BookingsListViewModelTests,BookingDetailViewModelTests,BookingCountdownTests,BookingPresentationTests,BookingCacheTests,BookingServiceListTests}.swift
```

### Documentation — READ BEFORE IMPLEMENTING

- `docs/api-contract.md` § Bookings, § Enums, § Error Format. `docs/prd-v1.md` §4.5, §7.2, §7.4.
- Apple: [TimelineView](https://developer.apple.com/documentation/swiftui/timelineview), [`Duration.UnitsFormatStyle`](https://developer.apple.com/documentation/foundation/duration/unitsformatstyle), [UIPasteboard.setItems(_:options:) expirationDate/localOnly](https://developer.apple.com/documentation/uikit/uipasteboard/1622104-setitems), [`ModelActor`](https://developer.apple.com/documentation/swiftdata/modelactor).

### Skills to Apply

`mvvm-architecture` (State enum, DI), `swiftui-development` (List, refreshable, accessibility, previews), `ios-api-client` (paging, offline), `ios-security-review` (privacy trace, pasteboard, app-switcher snapshot), `spotique-brand-ui`, `swift-actor-persistence` (SwiftData `@ModelActor` cache; never persist hidden fields), `swift-concurrency-6-2`.

### Patterns to Follow

- `@Observable @MainActor final class BookingsListViewModel`; single `State` enum: `idle | loading | loaded | empty | failed(APIError)`, plus orthogonal flags `isRefreshing`, `isLoadingMore`, `isShowingCachedData`, `loadMoreError`.
- Service methods `throws APIError`; models `nonisolated` (plan 01 NOTES).
- Logging: `Log.ui`/`Log.network`; booking IDs are fine at `.public`; never log `address`, `hostPhone`, `paymentMethodText`, `declineReason` (interpolate `.private` or omit).
- Tests: Swift Testing (`@Test`, `#expect`), `@MainActor` VMs, `StubURLProtocol`, fixtures copied from contract JSON, injected `now: () -> Date`.

---

## PRIVACY & SECURITY

| Booking stage | Driver may see | Enforcement |
|---|---|---|
| pending / declined / cancelled / completed | listing `display_address` (approximate), time, total, status, `decline_reason` (declined) | Server redacts `address`, `host_phone`, `payment_method_text` (contract). Client renders only `Booking` fields returned; `BookingContactSection` renders only when `status == .confirmed` **and** the field is non-nil. |
| confirmed | + full `address`, `host_phone`, `payment_method_text` | Server-provided only; never composed from coordinates/`display_address`. |

Rules:

1. **Redact on transition**: every refresh replaces the whole `Booking` (never merges fields), so a booking that moves confirmed → cancelled/completed loses address/phone from memory. `BookingDetailViewModel` additionally computes `contact` as `nil` unless `status == .confirmed`, in case a server bug returns them on another status (defense in depth; log a `.fault`-level, no-PII message).
2. **Never persisted**: `CachedBooking` has no attribute for `address`, `hostPhone`, `driverPhone`, `paymentMethodText`, or `declineReason` (host free text could contain a phone number). Cache writes go through `Booking.redactedForCache()` and a test asserts the schema has no such attributes. Cache rows carry `ownerUserID` and are cleared on sign-out (plan 01 `SessionStore.signOut`) and ignored if the owner differs.
3. **Offline confirmed booking**: shows status/time/total and "Address and host phone are available when you're online" — a product trade-off (Open Question 5).
4. **App-switcher/snapshot**: `BookingContactSection` swaps values for a redacted placeholder when `scenePhase != .active` and uses `.privacySensitive()`.
5. **Pasteboard**: `ios-security-review` discourages it; copy-phone is a requested feature, so use `UIPasteboard.general.setItems([[UTType.plainText.identifier: phone]], options: [.localOnly: true, .expirationDate: now+120s])`. No copy-address action.
6. **Call**: build `tel:` URL only from a validated E.164 string (`^\+[1-9]\d{7,14}$`); otherwise hide the Call button. No `open` of URLs from server text.
7. All list/detail calls require auth; a 401 flows through plan 01's handler (sign-out clears cache). Only the caller's own bookings are returned (server-enforced; client never queries by other user IDs).

## IMPLEMENTATION PLAN

### Phase 1: Foundation
Models (summaries, redaction helpers), `BookingRole`, `BookingListFilter`, service additions, cache, presentation/formatting/countdown pure logic.
### Phase 2: Core Implementation
`BookingsListViewModel`, `BookingDetailViewModel`, row/detail/contact/countdown views, `MyBookingsView`.
### Phase 3: Integration
Wire `AppEnvironment` (`bookingCache`), tab, `BookingsRoute` for plan 05 (post-submit) and plan 11 (deep link) entry, strings.
### Phase 4: Testing & Validation
Unit tests, previews (each status/Dynamic Type XXL/dark), manual privacy walkthrough.

---

## STEP-BY-STEP TASKS

Execute in order; run from `iOS/`. `TEST=` denotes `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### UPDATE Models/Booking.swift (+ Enums.swift)
- **IMPLEMENT**: Add optional, decode-tolerant summaries assumed from the API (Open Question 1): `listing: ListingSummary?` (`id, displayAddress, spotType, hostDisplayName`), `driver: PartySummary?` and `host: PartySummary?` (`id, displayName`, optional `ratingPositivePct`, `ratingCount`, `noShowCount`). Add `enum BookingRole: String { case host, driver }` (query value). Add helpers: `redactedForCache() -> Booking` (nil `address`, `hostPhone`, `driverPhone`, `paymentMethodText`, `declineReason`); `var duration: Duration`/`hours`; `var hasEnded(now)`; `isInProgress(now)`.
- **PATTERN**: plan 01 `Booking` (optional hidden fields); `.convertFromSnakeCase` naming.
- **GOTCHA**: Do not add any computed property that builds an address from lat/lng. Unknown `status` decodes to `.unknown` and renders as a neutral "Unknown status" badge with no contact details.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/ModelDecodingTests`

### UPDATE Services/BookingService.swift (adds only these to plan 05's file)
- **IMPLEMENT**: Add to `BookingServicing` and `LiveBookingService`:
  - `func bookings(role: BookingRole?, status: BookingStatus?, page: Int, perPage: Int) async throws -> PagedResponse<Booking>` → `GET /bookings?role=&status=&page=&per_page=` (omit nil params; default `perPage` 20; clamp 1...50).
  - `func booking(id: String) async throws -> Booking` → tries `GET /bookings/:id`; on `.notFound`/HTTP 405 for the *route* (Rails returns 404 for unknown routes, so ambiguous) falls back to `findInList(id:)`: page `GET /bookings` (no role) up to 5 pages × 50 until the ID appears, else throw `.notFound`. Remember "route unsupported" in a small lock-protected flag (`OSAllocatedUnfairLock<Bool>`) so later calls go straight to the fallback.
  - Plan 09 later adds `respond(...)`; plan 12 adds `reportNoShow`. Do **not** add them here.
- **PATTERN**: plan 05 `createBooking` endpoint construction; `ios-api-client` paging.
- **GOTCHA**: Contract gap: `GET /bookings/:id` missing (README gap 5). Real 404 on an existing route means "booking gone" — the fallback then also misses and the result is still `.notFound`, so the behaviour is correct either way, just one extra request.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingServiceListTests` (query string, envelope + meta decode, fallback scan, unsupported-route memo).

### CREATE Core/Storage/CachedBooking.swift and Services/BookingCache.swift
- **IMPLEMENT**: `@Model final class CachedBooking` (`id @Attribute(.unique)`, `ownerUserID`, `roleRaw`, `listingID`, `hostID`, `driverID`, `statusRaw`, `startTime`, `endTime`, `totalCents`, `noShow`, `createdAt`, `listingDisplayAddress?`, `spotTypeRaw?`, `counterpartyName?`, `cachedAt`). `protocol BookingCaching: Sendable { func load(ownerID:role:) async -> [Booking]; func store(_ bookings: [Booking], ownerID:role:, replacing: Bool) async; func clear() async }`; `SwiftDataBookingCache` as `@ModelActor`. `store` calls `redactedForCache()`. `load` returns `Booking` values (hidden fields nil). Register `CachedBooking` in `ModelContainerFactory` (live + in-memory) and wire `clear()` into sign-out.
- **PATTERN**: `swift-actor-persistence` skill (SwiftData default); `ModelContainerFactory` in plan 01.
- **GOTCHA**: No column for hidden fields, ever. `replacing: true` deletes that owner+role's rows first (used when page 1 succeeds) so deleted/old bookings don't linger; page 2+ append.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingCacheTests`

### CREATE Features/Bookings/BookingListFilter.swift, BookingPresentation.swift, BookingFormatting.swift, BookingCountdown.swift
- **IMPLEMENT**:
  - `BookingListFilter` (`struct`, `Sendable`, `matches(_:now:)`, `static let all`); plan 10 adds the rest.
  - `BookingPresentation(status:)`: `label` (Pending/Confirmed/Declined/Cancelled/Completed/Unknown), SF Symbol (`clock`, `checkmark.circle.fill`, `xmark.circle`, `slash.circle`/`nosign`, `flag.checkered`), badge tone, `accessibilityLabel`, `helperText` (e.g. pending: "Waiting for the host to respond"; cancelled: "This booking was cancelled"; declined: reason or "The host declined this request").
  - `BookingFormatting`: date-range string ("Sat, Jun 1 · 10 AM – 2 PM"), day-relative ("Today"/"Tomorrow") and total (`Int` cents → `FormatStyle.Currency`), all in `America/New_York` (constant from `Date+Extensions.swift`; add `MarketTime.zone` if plans 03/05 haven't); append zone abbreviation only when device zone differs.
  - `BookingCountdown.phase(now:start:end:) -> Phase` with `.upcoming(TimeInterval)`, `.startingSoon(TimeInterval)` (< 3600 s), `.inProgress(remaining: TimeInterval)`, `.ended`; plus `nextTick(after:) -> Date` (60 s while > 1 h out and while < 1 h out; `nil` once `.ended` or in progress with no display change → timeline stops).
- **PATTERN**: pure functions, no `Date()` inside; `now` injected.
- **GOTCHA**: Use absolute `Date` differences, never `Calendar` day math, for the countdown (DST-safe). For `.upcoming` beyond 24 h show days+hours; format text with `Duration.UnitsFormatStyle(allowedUnits: [.days,.hours,.minutes], width: .wide, maximumUnitCount: 2)` so pluralisation is localised; wrap as String Catalog key "Your booking starts in %@". < 1 min → "Your booking starts in less than a minute". In progress → "Your booking is in progress · ends in %@". Ended → "This booking has ended".
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingCountdownTests -only-testing:SpotiqueTests/BookingPresentationTests`

### CREATE Features/Bookings/BookingsListViewModel.swift
- **IMPLEMENT**: `init(role: BookingRole, service: BookingServicing, cache: BookingCaching, ownerID: String, now: @escaping () -> Date = Date.init, perPage: Int = 20)`. Observable: `state`, `bookings: [Booking]` (merged, dedup by `id`, later page wins), `filter: BookingListFilter = .all`, `visibleBookings` (filtered + sorted), `sections` (`upcoming` = pending/confirmed with `endTime > now`, sorted start asc; `earlier` = rest, start desc), `hasMore` (`page * perPage < total` using latest `meta`), `isRefreshing`, `isLoadingMore`, `isShowingCachedData`, `loadMoreError`, `lastRefreshedAt`. Actions: `load()` (first appear; cache first → show immediately → network), `refresh()` (pull-to-refresh; keeps list visible), `loadMoreIfNeeded(current: Booking)` (trigger when within 5 rows of end; ignored while `isLoadingMore`, offline/cached mode, or `!hasMore`), `retry()`, `refreshIfStale(maxAge: 30)` (tab re-appear/foreground), `apply(_ updated: Booking)` (upsert from detail/other flows).
- **PATTERN**: `mvvm-architecture` State enum; a generation counter cancels/ignores stale responses (refresh vs. loadMore race).
- **GOTCHA**: Page-1 success → `cache.store(replacing: true)`; later pages `replacing: false`. On `.offline`/URLError with cache non-empty → `state = .loaded`, `isShowingCachedData = true`; with empty cache → `.failed(.offline)`. Other errors with existing data keep the list and set a banner (`loadMoreError`/`refreshError`). `.unauthorized` is handled globally (do not toast). Empty result → `.empty`. Total `meta.total` may change between pages; dedup, never assume monotonic. Order is not specified by the contract — client sorts the loaded set (Open Question 4).
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingsListViewModelTests`

### CREATE Features/Bookings/BookingDetailViewModel.swift
- **IMPLEMENT**: `init(bookingID:, initial: Booking?, role: BookingRole, service:, cache:, ownerID:, now:)`. State `loading | loaded(Booking) | failed(APIError) | notFound`; `booking` (initial value shown immediately), `contact: RevealedContact?` (computed: non-nil only if `status == .confirmed` and at least one of `address`/`hostPhone`/`paymentMethodText` present; for role `.host`, driver phone equivalent per plan 09/10), `countdownVisible` (confirmed && !ended), `canCall`, `callURL`, `copyPhone()`, `refresh()`, `statusChangeAnnouncement: String?` (set when refresh changes `status`; view posts `AccessibilityNotification.Announcement`). `refresh()` runs on appear, on `scenePhase == .active`, and after pull-to-refresh; replaces `booking` wholesale.
- **GOTCHA**: `.notFound` after a listing/booking deletion → `notFound` state ("This booking is no longer available") — keep last known non-sensitive summary but drop contact. A booking cancelled because the host deleted the listing arrives as `status: cancelled` (no reason field — Open Question 6); render generic cancelled copy and do not require the listing to load.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingDetailViewModelTests`

### CREATE Features/Bookings/BookingRowView.swift, BookingCountdownView.swift, BookingContactSection.swift, BookingDetailView.swift
- **IMPLEMENT**:
  - `BookingRowView(booking:, role:, now:)`: line 1 counterparty/spot (driver role: `listing.displayAddress`, host name; host role: driver name), line 2 date range, trailing `StatusBadge`, total. Single element: `.accessibilityElement(children: .combine)` + explicit label "Confirmed. 34th Avenue, Jackson Heights. Saturday June 1, 10 AM to 2 PM. 20 dollars." Whole row ≥ 44pt, `NavigationLink(value: BookingsRoute.detail(...))`. Layout uses `ViewThatFits`/vertical stack at accessibility sizes.
  - `BookingCountdownView(start:, end:)`: `TimelineView(.explicit(dates))` from `BookingCountdown` ticks (60 s), `.accessibilityAddTraits(.updatesFrequently)`; renders static text when phase is `.ended`; timeline pauses automatically when the app is inactive.
  - `BookingContactSection(contact:)`: "Address", "Host phone" with **Call** (`Link`/`openURL`) and **Copy** buttons (44pt, labelled "Call host", "Copy phone number"), "Payment" text ("Pay the host directly: Cash or Venmo @janed"). Redacts to a placeholder when `scenePhase != .active`; `.privacySensitive()`.
  - `BookingDetailView<Extra: View>(viewModel:, @ViewBuilder extra: () -> Extra = { EmptyView() })`: sections — header (status badge + helper text + decline reason), when/duration/total, spot (approximate `displayAddress`), contact (confirmed only), countdown (confirmed), extras (plans 09/10/12 inject: driver info, rating, no-show). Pull-to-refresh; loading/error/notFound states with `ErrorBanner`/`EmptyStateView`.
- **PATTERN**: `swiftui-development`; `Card` for sections; brand tokens only; previews for every status (pending, confirmed, declined w/ reason, cancelled, completed, confirmed-in-progress, confirmed-offline w/o contact), XXL Dynamic Type, dark.
- **GOTCHA**: Never show a color-only status; badge = icon + text. Ensure Copy gives VoiceOver feedback ("Phone number copied") via announcement/haptic. Decline reason is server text: render as `Text(verbatim:)`, not markdown/LocalizedStringKey.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE Features/Bookings/MyBookingsView.swift, BookingsRoute.swift
- **IMPLEMENT**: `MyBookingsView` = `NavigationStack(path: $path)` over `List` with two sections ("Upcoming", "Earlier"), `.refreshable`, `EmptyStateView` ("No bookings yet" / "Find a spot on the map" action → `router.selectedTab = .explore`), inline `ErrorBanner` with retry, offline banner "Showing saved bookings" when `isShowingCachedData`, footer `ProgressView`/retry row for pagination. `BookingsRoute.detail(bookingID:)` destination builds `BookingDetailViewModel` with initial booking from `bookings`. `@State var path: [BookingsRoute]`; expose it so plan 05 (after submit: switch to Bookings tab + push new booking) and plan 11 (deep link) can push `.detail`.
- **GOTCHA**: Tab visible to `driver` and `both` roles only... hosts-only users have no driver tab (plan 01 tab rules). For `both`, this list is always `role: .driver`.
- **VALIDATE**: build + preview render.

### UPDATE App/AppEnvironment.swift and main tab view
- **IMPLEMENT**: Add `bookingCache: BookingCaching` (live: `SwiftDataBookingCache(modelContainer:)`; preview: `FakeBookingCache`); replace Bookings tab placeholder with `MyBookingsView`. Refresh via `scenePhase == .active` → `viewModel.refreshIfStale()`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### UPDATE Localizable.xcstrings
- **IMPLEMENT**: Add badge labels, helper texts, countdown formats ("Your booking starts in %@", in-progress, ended), empty/offline copy, a11y labels, Call/Copy. Use string-catalog plural variations where counts appear.
- **VALIDATE**: `xcodebuild … build`; confirm no stale/missing keys.

### CREATE tests, fakes and fixtures
- **IMPLEMENT**: see Testing Strategy. Extend `FakeBookingService` with configurable `bookings(...)`/`booking(id:)` results and call recording.
- **VALIDATE**: `TEST`

---

## TESTING STRATEGY

### Unit Tests (Swift Testing)
- **BookingsListViewModelTests**: initial load success → `.loaded`; empty → `.empty`; failure with no cache → `.failed`; offline + cache → loaded + `isShowingCachedData`; pull-to-refresh keeps list and replaces; pagination (page 2 appended, dedup on overlap, `hasMore` false at total, no duplicate load while `isLoadingMore`, loadMore error keeps list and is retryable); refresh during loadMore ignores stale response; sections/sort (upcoming asc, earlier desc, in-progress confirmed stays upcoming, `end == now` boundary is earlier); role passed as `.driver`; cache page-1 replace semantics; sign-out clear.
- **BookingDetailViewModelTests**: initial shown before fetch; refresh replaces wholesale — confirmed→cancelled clears `contact`; `contact` nil for pending even if fixture accidentally includes `address`/`host_phone` (defense in depth); confirmed w/o fields (offline cache) → nil contact + hint; declined shows reason; `.notFound` state; status change sets announcement; `callURL` only for valid E.164; fallback to list when detail route unsupported.
- **BookingCountdownTests** (injected `now`): > 24 h, exactly 1 h, 59 min, < 1 min, exactly at start (`inProgress`), 1 s before end, at end (`ended`), across a DST transition (2026-03-08 01:30→03:30 New York = 1 hour real), `nextTick` nil after end.
- **BookingPresentationTests**: every status → label/icon/a11y label; `.unknown` neutral.
- **BookingCacheTests** (in-memory container): stored rows contain no hidden data (assert model has no such properties and a round trip of `booking-confirmed.json` returns nil `address`/`hostPhone`/`paymentMethodText`); owner isolation; clear.
- **BookingServiceListTests**: query params, envelope+meta decode, `booking(id:)` fallback and memo.
- Fixtures: `booking-pending.json`, `booking-confirmed.json` (contract confirm example), `booking-declined.json` (with `decline_reason`), `booking-cancelled.json`, `bookings-page1.json` (20), `bookings-page2.json`.

### Edge Cases
Time zones (driver outside NYC), DST, booking in progress, past confirmed not yet `completed`, stale detail after server change, offline cold start, pagination shift, decline reason with markdown/emoji/very long text, Dynamic Type XXL, VoiceOver row reading, rapid tab switching.

## VALIDATION COMMANDS (from `iOS/`)

### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build` (no new warnings; no `print`, no force unwraps)
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`
### Level 3: Integration
Run against `StubURLProtocol` fixtures end to end (list → detail → refresh with status change).
### Level 4: Manual
Simulator with the API or a stub server: pending → confirm (from host) → verify reveal, call/copy, countdown ticks and stops at start; cancel/decline → contact disappears; airplane mode shows cached list without address/phone; grep the app container (`sqlite`, UserDefaults) for a fixture address/phone — must find none; app switcher hides contact.

## OPEN QUESTIONS

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Booking object has only `driver_id`/`host_id`/`listing_id` — rows need spot `display_address`, host name; host inbox needs driver name. Add embedded `listing`, `host`, `driver` summaries (or a listing fetch fallback: `GET /listings/:id` exists for the driver side; no user lookup exists for the host side). | New (contract gap) | Pending — assumed embedded summaries; fields optional in client |
| 2 | `GET /bookings/:id` missing. | README gap 5 | Client falls back to list scan; Pending |
| 3 | PRD says decline → "cancelled"; contract has separate `declined`. Client shows "Declined" (+ reason). Confirm. | PRD §4.3 vs contract | Assumed `declined` distinct |
| 4 | Ordering of `GET /bookings` unspecified; who moves `confirmed → completed` (no endpoint/job)? | Contract | Pending; client sorts locally and treats confirmed+ended as "earlier" |
| 5 | Offline, a confirmed driver cannot see address/host phone (never cached). Accept, or allow a Keychain-stored encrypted copy until `end_time`? | PRD §7.4 vs §7.2 | Assumed not cached; needs product/security sign-off |
| 6 | No `cancelled_by`/reason on bookings (host deleted listing vs host cancelled). | New | Generic cancelled copy |
| 7 | PRD §8 #2 auto-decline after 24 h; #5 driver cancel grace. | PRD §8 | Assumed no auto-decline UI and no driver cancel button; pending requests whose time passed show "Time has passed" helper text |
| 8 | Keep phone copy despite `ios-security-review` pasteboard guidance? Mitigated with local-only + 120 s expiry. | Skill vs request | Assumed yes |
| 9 | Show contact after `end_time` if the API still returns it? | New | Follow server |

## ACCEPTANCE CRITERIA

- [ ] My Bookings lists driver bookings with Pending / Confirmed / Declined / Cancelled / Completed badges (icon + text)
- [ ] Confirmed detail shows full address, host phone (call/copy) and payment text only when returned by the API for a `confirmed` booking
- [ ] Countdown "Your booking starts in X hours" updates on a timer, handles < 1 h, in progress, ended, and stops at start
- [ ] Declined shows the host's reason; cancelled (incl. listing deletion) renders without needing the listing
- [ ] Pull-to-refresh, pagination, empty/error/offline states; offline shows cached non-sensitive fields
- [ ] Refresh redacts contact when status leaves `confirmed`; nothing sensitive persisted or logged
- [ ] VoiceOver row labels, 44pt targets, Dynamic Type XXL, no color-only status
- [ ] All validation commands pass; no regressions; conventions followed
- [ ] Privacy model upheld (no early exposure of address/host phone)
- [ ] `docs/api-contract.md` updated if endpoints changed (request `GET /bookings/:id` + summaries)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Acceptance criteria met; open questions recorded with decisions
- [ ] Plans 09/10 confirmed to reuse `BookingsListViewModel`, `BookingRowView`, `BookingDetailView`

## NOTES

- **Execution order 05 → 06 → 09 → 10.** Methods added to `BookingService.swift`: plan 05 `createBooking`; **plan 06 `bookings(role:status:page:perPage:)` and `booking(id:)`**; plan 09 `respond(bookingID:decision:)`; plan 12 `reportNoShow(bookingID:)`.
- Sorting/filtering is client-side because `GET /bookings` accepts a single `status` and has no documented ordering; plan 10 builds Upcoming/Past/Cancelled on `BookingListFilter` without extra requests.
- Cache stores only what the pre-booking UI may already show (approximate address, times, total, status, counterparty name).
- Default MainActor isolation: `BookingCountdown`, `BookingFormatting`, `Booking.redactedForCache` are `nonisolated` pure code so tests and the `@ModelActor` cache can use them off the main actor.
- No polling; freshness comes from appear, foreground, pull-to-refresh, and push (plan 11 calls `refresh()`).
