# Feature: iOS Host Booking Inbox (Pending Requests, Accept / Decline)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types (plan 06 owns `BookingsListViewModel`, `BookingRowView`, `BookingDetailView`, `BookingFormatting`, `BookingRole`; plan 05 owns `BookingServicing`; plan 01 owns `AppRouter`, `StatusBadge`, `PagedResponse`), and import from the right files.

**Source:** `docs/prd-v1.md` §4.3 "P0 — Booking Inbox" (+ §4.7 notifications, §7.1, §7.2, §7.3, §8 #2); `docs/api-contract.md` "Bookings" (`GET /bookings`, `PATCH /bookings/:id`), "Errors", "Enums"; `iOS/plans/README.md`; `iOS/plans/01-foundation.md`; `iOS/plans/06-driver-bookings.md`.

## Feature Description

The host **Inbox** tab: all pending booking requests for the host's listings, soonest first, each card showing driver display name, requested date/time, duration and calculated total, with **Accept** and **Decline** actions (decline has an optional free-text reason in a sheet). Accepting confirms the booking and reveals the driver's phone to the host. The tab shows a badge with the pending count, and a request can be opened directly from a push notification.

## User Story

As a host / I want to see pending parking requests and accept or decline them quickly / So that drivers get an answer and I stay in control of who parks at my property.

## Problem Statement

Without an inbox, hosts cannot act on requests, drivers stay `pending` forever, and the host's push notification (plan 11) has nowhere to land. Accept/decline are consequential, can race with server state, and reveal personal data (driver phone), so they need careful state handling.

## Solution Statement

`HostInboxViewModel` (single, session-scoped instance owned by the main tab view so the tab badge and the screen share state) loads all pending host bookings via `GET /bookings?role=host&status=pending` (all pages, small set), sorts by `startTime` ascending, and performs `PATCH /bookings/:id` through `BookingServicing.respond`. Updates are **confirmed, not optimistic**: the card shows a per-card in-flight state until the server responds, then animates out. Any 404/409/422 triggers a reconcile fetch and a plain-language "already handled" message. The route type `HostInboxRoute.request(bookingID:)` is the deep-link target; plan 11 maps pushes to it.

## Requirements & Acceptance Criteria

Verbatim from PRD §4.3:

- List of all pending booking requests, sorted by start time (soonest first)
- Each request card shows: driver display name, requested date/time, duration, calculated total
- Accept and Decline buttons per request
- Accepted bookings reveal driver's phone number to host
- Push notification sent to host within 5 seconds of new booking request *(server; client in plan 11)*
- Tapping notification deep-links to the specific request
- Accept → booking status becomes "confirmed"; driver notified immediately
- Decline → booking status becomes "cancelled"; driver notified immediately *(contract: `declined`, see Open Questions)*
- Host can optionally add a decline reason (free text, shown to driver)

Contract:

- `PATCH /bookings/:id` body `{ "booking": { "status": "confirmed" } }` or `{ "booking": { "status": "declined", "decline_reason": "…" } }`; valid transitions `pending → confirmed | declined`, `confirmed → completed | cancelled`. Confirm response adds `address`, `host_phone`, `driver_phone`, `payment_method_text`.
- `GET /bookings?role=host&status=pending&page&per_page` returns `{ data, meta.pagination { page, per_page, total } }`.
- Errors: 403 `forbidden` (not host/wrong role), 404 `not_found`, 409/422 for invalid transition (code not specified — see Open Questions).

Additional (derived):

- Only users whose `role` is `host` or `both` see the Inbox tab; a role change to `driver` removes it and clears inbox state.
- PRD §7.3: 44pt targets, no color-only meaning, VoiceOver. PRD §7.4: offline shows last known list read-only; actions require connection.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium
**Platforms**: iOS (Api: `PATCH /bookings/:id`, driver display name on bookings — see gaps)
**Primary Systems Affected**: `iOS/Spotique/Features/HostInbox/`, `Services/BookingService.swift`, main tab view (tab + badge), `AppRouter` route consumption
**Dependencies**: Plans 05, 06 (and 07 for a host to have listings). No third-party libraries.

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING

- `iOS/Spotique/Services/BookingService.swift` (plans 05 + 06) — protocol/live shape; add `respond`.
- `iOS/Spotique/Features/Bookings/{BookingsListViewModel,BookingRowView,BookingDetailView,BookingDetailViewModel,BookingFormatting,BookingPresentation}.swift` (plan 06) — reuse formatting, detail, upsert semantics, redaction rules.
- `iOS/Spotique/Models/Booking.swift` — `driver: PartySummary?` (plan 06 addition), optional hidden fields.
- `iOS/Spotique/Core/DesignSystem/Components/{PrimaryButton,SecondaryButton,Card,ErrorBanner,EmptyStateView,StatusBadge}.swift`.
- `iOS/Spotique/Core/Networking/APIError.swift` — `.conflict`, `.notFound`, `.forbidden`, `.validation`, `.offline`.
- `iOS/Spotique/App/{AppRouter,AppEnvironment}.swift` and main tab view — tab set, `selectedTab`, `pendingDeepLink`.
- `iOS/SpotiqueTests/Fakes/FakeBookingService.swift`, `Fixtures/booking-pending.json`, `booking-confirmed.json`.

### New Files to Create

```
iOS/Spotique/Features/HostInbox/HostInboxView.swift             tab root, NavigationStack(path)
iOS/Spotique/Features/HostInbox/HostInboxViewModel.swift        list + actions + badge count
iOS/Spotique/Features/HostInbox/HostInboxRoute.swift            enum HostInboxRoute: Hashable { case request(bookingID: String) }
iOS/Spotique/Features/HostInbox/HostRequestCardView.swift       card with Accept / Decline
iOS/Spotique/Features/HostInbox/HostRequestDetailView.swift     wraps plan 06 BookingDetailView + action bar (deep-link target)
iOS/Spotique/Features/HostInbox/DeclineReasonSheet.swift        optional reason, counter
iOS/Spotique/Features/HostInbox/RequestCardModel.swift          view-facing value: name, time, duration, total, state; excludes phone
iOS/SpotiqueTests/Fakes/FakeBookingService.swift                (UPDATE: respond stubs)
iOS/SpotiqueTests/Fixtures/{booking-confirmed-host,bookings-pending-host,error-invalid-transition}.json
iOS/SpotiqueTests/{HostInboxViewModelTests,RespondEndpointTests,RequestCardModelTests}.swift
```

### Documentation — READ BEFORE IMPLEMENTING

- `docs/api-contract.md` § `PATCH /bookings/:id`, § `GET /bookings`, § Error Format. `docs/prd-v1.md` §4.3, §4.7, §7.2.
- Apple: [`badge(_:)` on tab items](https://developer.apple.com/documentation/swiftui/view/badge(_:)-84e43), [`AccessibilityNotification.Announcement`](https://developer.apple.com/documentation/swiftui/accessibilitynotification/announcement), [`sensoryFeedback`](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)).

### Skills to Apply

`mvvm-architecture`, `swiftui-development`, `ios-api-client` (mutations, idempotency, error mapping), `ios-security-review` (driver phone handling), `spotique-brand-ui`, `swift-concurrency-6-2`.

### Patterns to Follow

- Plan 06 patterns: State enum, `now` injection, `nonisolated` pure helpers, `Text(verbatim:)` for server-provided text (`driver.displayName`, `declineReason`).
- Mutation pattern: `inFlight: [String: RequestAction]` guard at VM level (not only `.disabled` in the view) — second call for the same ID returns immediately.
- Logging: booking ID and action at `.public`; never the driver phone or reason text.

---

## PRIVACY & SECURITY

| Stage | Host sees | Enforcement |
|---|---|---|
| pending | driver display name, time, total, listing (their own) | Server. `RequestCardModel` never carries `driverPhone`. |
| confirmed | + `driver_phone` (from API), `payment_method_text` (own), `address` (own) | Rendered only when `status == .confirmed` and value non-nil. |

- **Reconciling driver phone timing**: contract §7.2/`PATCH` notes say the host "receives driver's phone number on booking creation", yet `POST /bookings` returns no `driver_phone`, `GET /bookings` says only confirmed bookings include it, and PRD §4.3 says "accepted bookings reveal driver's phone". The client is conservative: **the host UI shows the driver phone only when `status == .confirmed`** and the API returned it. If the server includes `driver_phone` on pending items (per §7.2), the client ignores it (not mapped into card models; cache excludes it). Flagged for product/API decision (Open Question 2).
- Host-only endpoint: `PATCH` requires host role; a 403 shows "You can't respond to this request" and refreshes.
- The confirm response is the only reveal moment; hold the returned `Booking` in memory only (detail view), never in the cache (plan 06 `redactedForCache`).
- Decline reason is free text sent to the driver: trimmed, max 280 chars client-side, sent as JSON via encoder (no string building), omitted when empty. Never logged. Do not display "reason" for a phone-number-looking text differently; nothing to sanitise beyond length.
- Deep links carry only a booking ID; the client fetches by ID under auth — a stale/forged ID resolves to `.notFound`/403, never displaying another user's data.
- Screenshots/app switcher: driver phone in the detail uses plan 06's `privacySensitive` placeholder behaviour.

## IMPLEMENTATION PLAN

### Phase 1: Foundation
`BookingServicing.respond`, `HostDecision`, `RequestCardModel`, `HostInboxRoute`.
### Phase 2: Core Implementation
`HostInboxViewModel` (load-all, sort, badge, actions, reconcile), views (card, sheet, detail, tab root).
### Phase 3: Integration
Tab + badge in main tab view (role-gated), deep-link consumption hook, `AppEnvironment` (no new service), strings.
### Phase 4: Testing & Validation
State-machine tests, endpoint tests, previews, manual flow with two accounts.

---

## STEP-BY-STEP TASKS

Run from `iOS/`. `TEST=` = `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### UPDATE Services/BookingService.swift (adds only `respond`)
- **IMPLEMENT**: `enum HostDecision: Sendable, Equatable { case accept; case decline(reason: String?) }` and `func respond(bookingID: String, decision: HostDecision) async throws -> Booking` → `PATCH /bookings/:id` with `{"booking":{"status":"confirmed"}}` or `{"booking":{"status":"declined","decline_reason":…}}` (reason trimmed, omitted if empty). Returns the decoded `Booking` (`data`). Convenience wrappers optional (`accept(bookingID:)`, `decline(bookingID:reason:)`) — keep protocol surface to `respond`.
- **PATTERN**: plan 05 `createBooking` body encoding (nested `booking` object, snake_case via shared encoder); plan 06 `bookings(...)`.
- **GOTCHA**: Do not retry automatically (non-idempotent from the UI's viewpoint). Only `bookings(role:status:page:perPage:)`/`booking(id:)` come from plan 06 — do not redefine.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/RespondEndpointTests` (path, method PATCH, exact bodies, confirm response decode incl. `driver_phone`, 409/422/404/403 mapping)

### CREATE Features/HostInbox/HostInboxRoute.swift and RequestCardModel.swift
- **IMPLEMENT**: `enum HostInboxRoute: Hashable { case request(bookingID: String) }`. `RequestCardModel` (`id`, `driverName`, `dateRangeText`, `durationText`, `totalText`, `listingLabel?`, `isExpired`, `actionState: RequestAction?`, `accessibilityLabel`) built from `Booking` + `now` via plan 06 `BookingFormatting`; duration as "3 hours" (`Duration.UnitsFormatStyle`); total from `Int` cents.
- **PATTERN**: plan 06 `BookingFormatting`; no phone field on the model.
- **GOTCHA**: Missing `driver.displayName` (contract gap) → show "Driver" plus a `Log` fault so the gap is visible; never show `driver_id`. `isExpired = booking.endTime <= now`.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/RequestCardModelTests`

### CREATE Features/HostInbox/HostInboxViewModel.swift
- **IMPLEMENT**: `@Observable @MainActor final class HostInboxViewModel`, `init(service: BookingServicing, cache: BookingCaching, ownerID: String, now: @escaping () -> Date = Date.init)`.
  - State: `state: .idle | .loading | .loaded | .empty | .failed(APIError)`; `requests: [Booking]` (pending only, sorted `startTime` asc then `createdAt` asc); `cards: [RequestCardModel]` (actionable first, expired last, "Expired" section); `pendingCount` (actionable = `endTime > now`; used for tab badge); `inFlight: [String: RequestAction]` (`.accepting`/`.declining`); `banner: InboxBanner?` (info/error, auto-dismiss ~4 s or on next action); `isShowingCachedData`; `path: [HostInboxRoute]`; `lastRefreshedAt`.
  - Actions: `load()`, `refresh()`, `refreshIfStale(maxAge: 30)`, `accept(_ id:)`, `decline(_ id:, reason:)`, `open(_ route: HostInboxRoute)` (deep link: append to `path`; if booking not in `requests`, `loadRequest(id:)` via `service.booking(id:)`), `reset()` (role change/sign-out).
  - `load/refresh`: fetch pages with `status: .pending, role: .host, perPage: 50` until `page * perPage >= total` (cap 10 pages), keep `meta.total` as authoritative `serverPendingCount` (badge shows `max(pendingCount, 0)` from actionable loaded items; if capped, show server total). Empty → `.empty`. Offline: show cached (redacted, plan 06 cache, role `.host`) read-only with `isShowingCachedData`; actions disabled.
  - `accept/decline`: `guard inFlight[id] == nil` → set in-flight → `respond` → on success remove from `requests`, `apply` updated booking to plan 06 cache-safe upsert, decrement badge, banner "Booking confirmed" / "Request declined", announce, haptic (`.success`). Confirmed `Booking` (with `driverPhone`) is exposed via `lastConfirmed: Booking?` for the detail/toast link only, and cleared when the user leaves the screen or after 2 minutes.
- **PATTERN**: plan 06 `BookingsListViewModel` generation counter for stale responses; `mvvm-architecture`.
- **GOTCHA**:
  - **Not optimistic**: no removal before the server answers (accept reveals data and can fail on state). Perceived speed via immediate in-card spinner; PRD §7.1 targets < 2 s.
  - **Errors**: `.conflict`/`.validation`/`.notFound` (any code other than a field error) → treat as stale: `booking(id:)` reconcile; if status != pending remove the card and banner "This request was already {confirmed/declined/cancelled}"; if 404 remove with "This request is no longer available" (e.g., driver/listing removed). `.forbidden` → "You can't respond to this request" + refresh. `.offline`/timeout after send → outcome unknown: reconcile via `booking(id:)` before re-enabling buttons (prevents double-accept confusion); if reconcile also offline, keep card with "Couldn't confirm the result — retry" state. `.unauthorized` handled globally.
  - Decline sheet dismissal while in flight is disabled; second submit blocked by `inFlight`.
  - Refresh during an in-flight action must not resurrect the card: filter out IDs present in `inFlight` and IDs answered in this session until the next server snapshot excludes them.
  - Expired pending items (`endTime <= now`) can't be accepted client-side: Accept disabled with reason "Request time has passed"; Decline still allowed to notify the driver (Open Question 3).
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/HostInboxViewModelTests`

### CREATE Features/HostInbox/HostRequestCardView.swift and DeclineReasonSheet.swift
- **IMPLEMENT**: `Card` with driver name (headline), date range, "3 hours · $45.00", listing label when host has several listings, and two buttons (Decline = `SecondaryButton`, Accept = `PrimaryButton`) each ≥ 44pt; while `actionState != nil` show `ProgressView` on the pressed button and disable both; Expired shows a text badge ("Expired" + icon) with Accept disabled. Card body taps → `HostInboxRoute.request`. `.accessibilityElement(children: .contain)`, custom label "Request from Raj S. Saturday June 1, 2 to 5 PM, 3 hours, 45 dollars", actions exposed via `accessibilityAction(named:"Accept")`/`"Decline"` in addition to buttons. `DeclineReasonSheet`: `TextEditor` (placeholder "Reason (optional) — shown to the driver"), live counter (280), buttons "Decline request" (destructive style, icon+text) and "Cancel"; `presentationDetents([.medium])`; keyboard-safe; text is `verbatim`.
- **PATTERN**: plan 01 components; `swiftui-development`.
- **GOTCHA**: Layout at accessibility sizes stacks buttons vertically (`ViewThatFits`). Do not add a confirmation alert for Accept (PRD flow is one tap) but do for nothing else — decline uses the sheet as its confirmation.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build` + previews (normal, in-flight, expired, XXL, dark)

### CREATE Features/HostInbox/HostRequestDetailView.swift
- **IMPLEMENT**: Uses plan 06 `BookingDetailView(viewModel:) { extra }` with `role: .host`; extras: **Driver** section (name; phone with Call/Copy only when confirmed and returned; plan 12 later adds rating summary/no-show). Bottom `safeAreaInset` action bar (Accept/Decline) only when the refreshed status is `pending`; otherwise a status line "Already confirmed/declined" and no buttons. Shares actions with `HostInboxViewModel` (passed in) so the card list updates when acting from detail; after success pop to list.
- **PATTERN**: plan 06 `BookingContactSection` privacy behaviours (scenePhase redaction, E.164 check).
- **GOTCHA**: Deep-linked cold start: booking may not be in the loaded list — VM loads by ID and shows a skeleton; on `.notFound` show `EmptyStateView` "This request is no longer available" with a button to the inbox.
- **VALIDATE**: build + preview

### CREATE Features/HostInbox/HostInboxView.swift
- **IMPLEMENT**: `NavigationStack(path: $viewModel.path)`; `List` with sections "Needs response" and "Expired"; `.refreshable`; `EmptyStateView` ("No pending requests" / "New requests will appear here"); `ErrorBanner` with retry; offline banner; `navigationDestination(for: HostInboxRoute.self)`; task on appear + `scenePhase == .active` → `refreshIfStale()`. Toolbar button (icon `clock.arrow.circlepath`, label "History") pushes plan 10 `BookingHistoryView(role: .host)` (add once plan 10 exists).
- **GOTCHA**: Do not create the ViewModel inside the view's `body`; it is owned by the tab view (`@State`) so the badge works before the tab is first selected.
- **VALIDATE**: build

### UPDATE main tab view and AppRouter usage
- **IMPLEMENT**: Show `Tab("Inbox", systemImage: "tray")` only when `sessionStore.currentUser?.role` ∈ {`.host`, `.both`}; `.badge(inboxViewModel.pendingCount)` (0 hides; VoiceOver reads "Inbox, 3 pending"). Create `HostInboxViewModel` when the role qualifies; call `reset()` and drop it when the role changes to `driver` or on sign-out; trigger an initial `load()` at sign-in for hosts so the badge is populated (single small request; not on the launch critical path — after first frame). Deep-link hook: when `router.pendingDeepLink` resolves to a host request (mapping owned by plan 11), set `router.selectedTab = .inbox` and call `inboxViewModel.open(.request(bookingID:))`, then clear the link. Plan 11 also calls `inboxViewModel.refresh()` on a foreground push.
- **PATTERN**: plan 01 tab/role visibility rules; `mvvm-architecture` navigation.
- **GOTCHA**: `both` users: this tab is host-side only; driver bookings live in My Bookings (plan 06, `role: .driver`).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### UPDATE Localizable.xcstrings
- **IMPLEMENT**: Titles, empty/expired copy, accept/decline labels, banners ("Booking confirmed", "This request was already %@"), sheet text, a11y labels; plural variations for "%lld pending".
- **VALIDATE**: build; no stale keys.

### CREATE tests, fixtures, fake updates
- **IMPLEMENT**: as in Testing Strategy; `FakeBookingService.respond` supports queued results/errors and suspension (to test double-tap while in flight).
- **VALIDATE**: `TEST`

---

## TESTING STRATEGY

### Unit Tests (Swift Testing, `@MainActor`)
- **HostInboxViewModelTests**: load multi-page → all merged, sorted soonest first (ties by `createdAt`), `pendingCount` correct; empty → `.empty`; failure → `.failed`; offline + cache → read-only cached; accept success → card removed, banner, confirmed booking exposed once, badge decremented; decline with reason → body includes trimmed reason, empty reason omitted; decline reason > 280 truncated/blocked; **double-tap** (two `accept` calls while suspended → one `respond`); accept then decline of same ID ignored; refresh mid-flight does not resurrect the card; 409 / 422 / 404 → reconcile + correct banner + card removed when status not pending; 403 → banner + refresh; offline mid-action → reconcile path, buttons stay locked until known; expired request Accept disabled and excluded from badge; `open(.request(id))` when list empty loads by ID; `reset()` clears state; role change drops VM.
- **RequestCardModelTests**: driver name/time/duration/total strings (market time zone, DST week: 2026-03-08 booking spanning 2 AM), missing driver name fallback, **no phone field** even when the fixture includes `driver_phone` on a pending booking, VoiceOver label content.
- **RespondEndpointTests**: request shapes, `driver_phone` present on confirm decode, error mapping.
- Fixtures: `booking-pending.json` (contract), `booking-confirmed-host.json` (contract confirm example), `bookings-pending-host.json` (3 items out of order across 2 pages), `error-invalid-transition.json` (assumed shape).

### Edge Cases
Two hosts' devices/two tabs (stale accept), request time passing while the screen is open (a timer/`refreshIfStale` recomputes `isExpired`), host with several listings, host with 0 listings (empty state copy suggests creating a listing → plan 07), very long driver names, RTL, Dynamic Type XXL, tab badge > 99 ("99+"), role switching, sign-out mid-action.

## VALIDATION COMMANDS (from `iOS/`)

### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`
### Level 3: Integration
Full inbox flow against `StubURLProtocol`: load → accept → detail shows driver phone → refresh after server transition.
### Level 4: Manual
Two simulators/accounts (driver requests, host responds): card appears sorted; accept reveals phone in detail only; decline sheet with/without reason shows in driver's My Bookings; badge updates; a push tap (once plan 11 lands) opens the right request; airplane mode disables actions.

## OPEN QUESTIONS

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Booking has no driver display name (`driver_id` only). Need embedded `driver { display_name, … }` (plan 06 Q1). Blocks the card. | Contract gap | Pending — assumed embedded |
| 2 | Driver phone timing: contract/§7.2 says host gets it at creation; PRD §4.3 says after accept; `POST` and `GET` responses omit it for pending. | PRD vs contract | Assumed after accept only |
| 3 | Pending requests whose time has passed: server behaviour on accept? Auto-decline after 24 h? | PRD §8 #2 | Assumed no auto-decline UI; expired cards can only be declined |
| 4 | PRD: decline → "cancelled"; contract: `declined`. Client sends `declined`. | PRD §4.3 vs contract | Assumed `declined` |
| 5 | Error code/status for invalid transition (already accepted, etc.). | Contract | Handled generically (409/422/404) |
| 6 | `per_page` maximum (client asks 50). `GET /bookings/:id` missing (plan 06 fallback). | Contract | Pending |
| 7 | Max length of `decline_reason` server-side (client caps 280). | Contract | Pending |
| 8 | Badge count source: server-provided pending total vs loaded actionable count. | New | Loaded actionable, server total if capped |
| 9 | Should Accept require a confirmation dialog? | New | No (single tap, per PRD flow) |

## ACCEPTANCE CRITERIA

- [ ] Inbox lists pending requests soonest first; each card shows driver name, date/time, duration, total
- [ ] Accept and Decline per card; decline sheet has optional free-text reason (≤ 280) that is sent to the API
- [ ] Accept updates the booking to confirmed, removes the card, and the driver's phone is available to the host only after confirmation
- [ ] Double-tap protection; 404/409/422/403/offline handled without stale or duplicate cards
- [ ] Inbox tab visible only to host/both and shows a pending-count badge (with accessible label)
- [ ] `HostInboxRoute.request(bookingID:)` exists and opens the request detail (deep-link ready for plan 11)
- [ ] VoiceOver, 44pt targets, Dynamic Type XXL, no color-only meaning
- [ ] All validation commands pass; no regressions; conventions followed
- [ ] Privacy model upheld (no early exposure of address/host phone; driver phone only after confirm; nothing sensitive cached or logged)
- [ ] `docs/api-contract.md` updated if endpoints changed (driver summary, `GET /bookings/:id`, error codes)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Acceptance criteria met; open questions recorded with decisions

## NOTES

- **Methods this plan adds to `BookingService.swift`: only `respond(bookingID:decision:)`** (plan 06 supplies `bookings`/`booking(id:)`; plan 12 adds `reportNoShow`). Execution order 05 → 06 → 09 → 10.
- Pessimistic updates were chosen because accept exposes data and the server is the arbiter of transitions; rollback logic would add complexity without real speed gain.
- The overlap rule (pending + confirmed) means two overlapping pending requests cannot coexist, so accepting one should not conflict with another; a server-side conflict, if it appears, falls into the generic stale path.
- The inbox VM is session-scoped and role-gated so the badge works without visiting the tab; it is cleared on sign-out/role change (privacy: confirmed booking data held only transiently in `lastConfirmed`).
- Default MainActor isolation: `RequestCardModel` formatting helpers and `HostDecision` are `nonisolated`/`Sendable`.
