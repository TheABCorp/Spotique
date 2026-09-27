# Feature: iOS Booking History (Upcoming / Past / Cancelled, All Users)

> Validate documentation, codebase patterns, and task sanity before implementing. This plan is deliberately thin: it reuses plan 06 (`BookingsListViewModel`, `BookingRowView`, `BookingDetailView`, `BookingListFilter`, cache) and plan 09 (host detail extras). Do not fork or duplicate them.

**Source:** `docs/prd-v1.md` §4.3 "P1 — Booking History" and §4.8 "P1 — User Profile" item "Booking history (all users)" (+ §7.3, §7.4, §8 #2, #5); `docs/api-contract.md` "Bookings" (`GET /bookings`), "Enums"; `iOS/plans/README.md`; plans 01, 06, 09.

## Feature Description

A **Booking History** screen that lists every booking a user has (as driver, as host, or both) with three filter tabs — **Upcoming**, **Past**, **Cancelled** — and a full booking detail on tap. Hosts see driver info, time, total and payment text; drivers see the same detail as in My Bookings. The screen is reachable from the host Inbox toolbar and from the **Booking history** section of Profile (plan 13).

## User Story

As a host or driver / I want to browse all my past, upcoming and cancelled bookings and open any of them / So that I can check what happened, what was charged, and who I dealt with.

## Problem Statement

My Bookings (plan 06) is a working list for active drivers, and the Inbox (plan 09) only shows pending requests. Nobody can review completed or cancelled bookings, and hosts have no list of their confirmed/past guests. The PRD requires a full history for all users with filter tabs and full detail.

## Solution Statement

`BookingHistoryView` hosts a filter picker and one `BookingsListViewModel` per role, whose `filter` property (a client-side `BookingListFilter`) selects Upcoming/Past/Cancelled from a single unfiltered dataset. Because `GET /bookings` supports only one `status` value and no ordering, filtering is client-side and the view model **auto-fills** additional pages when a filter tab shows too few matches. Rows and detail are plan 06 components; host detail injects a `HostBookingExtras` section. `both` users get an "As driver / As host" segmented control.

## Requirements & Acceptance Criteria

Verbatim from PRD §4.3 P1:

- Full list of all bookings (upcoming, past, cancelled) with filter tabs
- Tap any booking to see full detail: driver info, time, total, payment method used

PRD §4.8: Booking history (all users) in the profile.

Filter mapping (this plan, evaluated with an injected `now`):

| Tab | Rule | Sort |
|---|---|---|
| Upcoming | `status ∈ {pending, confirmed}` and `endTime > now` (includes in progress) | `startTime` ascending |
| Past | `status == completed`, or `status ∈ {pending, confirmed}` with `endTime <= now` (a confirmed booking the server hasn't marked completed; a request nobody answered) | `startTime` descending |
| Cancelled | `status ∈ {cancelled, declined}` (declined keeps its "Declined" badge and reason) | `startTime` descending |
| `.unknown` status | appears only in Past with a neutral badge | — |

Every booking appears in exactly one tab (tested exhaustively).

Contract constraints that shape detail: non-confirmed bookings have `address`, `host_phone`, `driver_phone` and `payment_method_text` **redacted** by the server; so "payment method used" and driver phone can only be shown for bookings still `confirmed` when fetched (see Open Questions 1–2).

## Feature Metadata

**Feature Type**: New Capability (built almost entirely from plan 06 parts)
**Estimated Complexity**: Low-Medium
**Platforms**: iOS (Api: no new endpoints required; benefits from `GET /bookings/:id`, sort param)
**Primary Systems Affected**: `iOS/Spotique/Features/BookingHistory/`, `Features/Bookings/BookingListFilter.swift` + `BookingsListViewModel.swift` (small additive updates), Inbox toolbar entry, Profile entry (plan 13)
**Dependencies**: Plans 06 and 09 (and 13 embeds it). Ratings hooks (plan 12) add to the detail extras later.

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING

- `iOS/Spotique/Features/Bookings/BookingsListViewModel.swift` (plan 06) — `role`, `filter`, `visibleBookings`, `sections`, `hasMore`, `loadMoreIfNeeded`, cache semantics, generation counter.
- `iOS/Spotique/Features/Bookings/BookingListFilter.swift` (plan 06) — `.all` + `matches(_:now:)`.
- `iOS/Spotique/Features/Bookings/{BookingRowView,BookingDetailView,BookingDetailViewModel,BookingContactSection,BookingPresentation,BookingFormatting}.swift` — reuse as-is; detail has the `extra` slot.
- `iOS/Spotique/Features/HostInbox/HostRequestDetailView.swift` (plan 09) — driver section pattern to extract/share (`DriverInfoSection`).
- `iOS/Spotique/Services/{BookingService,BookingCache}.swift`; `Models/Booking.swift` (`driver`, `listing` summaries).
- `iOS/Spotique/App/{AppEnvironment,AppRouter}.swift`; `SessionStore.currentUser?.role`.
- `iOS/Spotique/Core/DesignSystem/Components/{EmptyStateView,ErrorBanner,StatusBadge}.swift`.

### New Files to Create

```
iOS/Spotique/Features/BookingHistory/BookingHistoryView.swift         role picker + filter tabs + list
iOS/Spotique/Features/BookingHistory/BookingHistoryViewModel.swift    owns per-role BookingsListViewModel, selected tab, role
iOS/Spotique/Features/BookingHistory/BookingHistoryTab.swift          enum upcoming/past/cancelled -> BookingListFilter, titles, empty copy
iOS/Spotique/Features/BookingHistory/BookingHistoryRoute.swift        enum BookingHistoryRoute: Hashable { case detail(bookingID: String, role: BookingRole) }
iOS/Spotique/Features/BookingHistory/HostBookingExtras.swift          driver info + payment text section for host detail
iOS/Spotique/Features/BookingHistory/BookingHistoryEntry.swift        small helpers: default role for a user, entry-point view for Profile/Inbox
iOS/SpotiqueTests/{BookingHistoryFilterTests,BookingHistoryViewModelTests}.swift
iOS/SpotiqueTests/Fixtures/{bookings-history-mixed}.json
```
Files updated: `BookingListFilter.swift`, `BookingsListViewModel.swift` (auto-fill), `HostRequestDetailView.swift` (extract `DriverInfoSection` into shared file `Features/Bookings/DriverInfoSection.swift`), `HostInboxView.swift` (toolbar link).

### Documentation — READ BEFORE IMPLEMENTING

- `docs/api-contract.md` § `GET /bookings` (query params, redaction sentence). `docs/prd-v1.md` §4.3, §4.8.
- Apple: [`Picker` with `.segmented`](https://developer.apple.com/documentation/swiftui/pickerstyle/segmented), [`Calendar` / time zones](https://developer.apple.com/documentation/foundation/calendar).

### Skills to Apply

`mvvm-architecture`, `swiftui-development`, `ios-api-client` (paging/offline), `ios-security-review`, `spotique-brand-ui`, `swift-actor-persistence` (cache reuse only).

### Patterns to Follow

Plan 06 patterns: State enum; `now` injection; generation counter; dedup merge; redacted cache. Plan 09 pattern: `Text(verbatim:)` for server text. Pure predicate + table-driven tests for classification.

---

## PRIVACY & SECURITY

- History never adds a data path: it uses `GET /bookings` results as-is. Address, phone and payment text render only for `status == .confirmed` **and** when returned, via plan 06's `BookingContactSection`/`contact` computed property. Past/cancelled/declined/completed items therefore show none of them (server redaction + client gate).
- Cache: reuses plan 06's `BookingCaching` (non-sensitive fields only, keyed by owner + role, cleared on sign-out). History can hold many rows, so the cache prunes to the most recent 200 per owner+role on write.
- The host's view of driver info is limited to display name and public rating summary (no phone unless confirmed and returned; plan 12 supplies the summary).
- "Payment method used": off-platform payments mean the app never knows which method was actually used; UI labels the text "Payment (as listed by host)" to avoid implying a record.
- No search/export/share of history in MVP (would risk leaking data via share sheets).
- Auth required; 401 handled by plan 01; a `both` user's role toggle queries only `role=host` or `role=driver`.

## IMPLEMENTATION PLAN

### Phase 1: Foundation
`BookingHistoryTab` → `BookingListFilter` statics (pure, tested), auto-fill in `BookingsListViewModel`, shared `DriverInfoSection`.
### Phase 2: Core Implementation
`BookingHistoryViewModel`, `BookingHistoryView`, host extras/detail wiring.
### Phase 3: Integration
Inbox toolbar entry; entry view for Profile (plan 13) with role default; strings; previews.
### Phase 4: Testing & Validation

---

## STEP-BY-STEP TASKS

Run from `iOS/`. `TEST=` = `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### UPDATE Features/Bookings/BookingListFilter.swift
- **IMPLEMENT**: Add `static let upcoming`, `.past`, `.cancelled` implementing the mapping table (predicate + `sortOrder` (`.startAscending`/`.startDescending`) + `id`). Keep `.all` (plan 06 default, used by My Bookings).
- **PATTERN**: plan 06 `BookingListFilter.matches(_:now:)`; pure, `nonisolated`, `Sendable`.
- **GOTCHA**: Boundaries — `endTime == now` is Past, `startTime == now` with `endTime > now` is Upcoming (in progress). Compare `Date`s directly (no calendar-day comparison; DST-safe). Filters must partition all statuses including `.unknown`.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingHistoryFilterTests`

### UPDATE Features/Bookings/BookingsListViewModel.swift (additive)
- **IMPLEMENT**: Make `visibleBookings` apply `filter` then the filter's sort order (plan 06 default `.all` behaviour unchanged). Add `minimumVisible: Int` (default 0; history sets 10) and `loadUntilFilled(maxPages: Int = 5)`: after a load/refresh/filter change, while `visibleBookings.count < minimumVisible && hasMore && !isOffline`, load next page (max 5 per trigger); `loadMoreIfNeeded` continues to work by scroll. Cache pruning limit param (200).
- **PATTERN**: plan 06 generation counter; ignore auto-fill results if the filter or role changed meanwhile (cancel the `Task`).
- **GOTCHA**: Guard against infinite loops when the server total shrinks; stop when a page adds no new IDs. Do not show a spinner-only screen while auto-filling: show what matched so far plus a footer `ProgressView`. An empty tab with `hasMore == true` shows "Looking for more…" not the empty state.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingsListViewModelTests -only-testing:SpotiqueTests/BookingHistoryViewModelTests`

### CREATE Features/BookingHistory/BookingHistoryTab.swift and BookingHistoryRoute.swift
- **IMPLEMENT**: `enum BookingHistoryTab: CaseIterable, Identifiable { upcoming, past, cancelled }` with `title`, `systemImage`, `filter`, `emptyTitle/emptyMessage` (e.g. "No upcoming bookings", "No cancelled bookings"). `BookingHistoryRoute.detail(bookingID:role:)`.
- **VALIDATE**: build

### CREATE Features/BookingHistory/BookingHistoryViewModel.swift
- **IMPLEMENT**: `@Observable @MainActor final class BookingHistoryViewModel`, `init(user: User, initialRole: BookingRole? = nil, service:, cache:, now:)`. State: `availableRoles: [BookingRole]` (`.driver` → [driver]; `.host` → [host]; `.both` → [driver, host]), `role`, `tab: BookingHistoryTab = .upcoming`, `listViewModel: BookingsListViewModel` (lazy per role, cached in a dictionary so switching role/tab preserves scroll data and avoids re-fetch), `path: [BookingHistoryRoute]`. Actions: `select(tab:)` (sets `listViewModel.filter`, triggers `loadUntilFilled`), `select(role:)`, `onAppear()` (`refreshIfStale`), `reset()`.
- **PATTERN**: plan 09 session-scoped VM ownership; `mvvm-architecture`.
- **GOTCHA**: Role must come from `SessionStore.currentUser` at creation; if the user's role changes (Profile toggle, plan 13) recreate the VM (`.id(user.role)`), and never show a role the user doesn't hold. A host who later became driver-only can still have host-side history on the server — out of scope; only current roles are shown (Open Question 4).
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/BookingHistoryViewModelTests`

### CREATE Features/BookingHistory/BookingHistoryView.swift
- **IMPLEMENT**: `NavigationStack` (when standalone) or content-only when pushed (Profile/Inbox already provide a stack — expose `BookingHistoryContent` + a wrapper). Layout: optional role `Picker` (segmented, "As driver"/"As host") only when `availableRoles.count > 1`; filter `Picker(.segmented)` bound to `tab` (labels are text; segmented control is already accessible; add `accessibilityValue`); `List` of `BookingRowView` (rows from plan 06, `NavigationLink(value:)`); `.refreshable`; footer pagination row; offline banner "Showing saved bookings" when cached; per-tab `EmptyStateView`; `ErrorBanner` with retry; navigation title "Booking history". Detail destination builds `BookingDetailView` with role-specific extras: for `.host` → `HostBookingExtras`.
- **PATTERN**: plan 06 `MyBookingsView`; `swiftui-development` (`List`, `.refreshable`).
- **GOTCHA**: Segmented control with Dynamic Type XXL truncates — switch to a `Menu`/scrollable chip row at accessibility sizes (`@Environment(\.dynamicTypeSize).isAccessibilitySize`). Announce tab change results ("Past, 12 bookings" only when loaded; avoid noisy announcements while auto-filling).
- **VALIDATE**: build + previews (each tab empty/populated, both role, offline, XXL, dark)

### CREATE Features/BookingHistory/HostBookingExtras.swift; ADD Features/Bookings/DriverInfoSection.swift
- **IMPLEMENT**: `DriverInfoSection(driver: PartySummary?, phone: String?)` shared with plan 09 detail: display name; (rating summary slot — filled by plan 12 via an optional closure); phone with Call/Copy only when passed in (i.e., confirmed + returned). `HostBookingExtras`: Driver section, "Payment (as listed)" line from `booking.paymentMethodText` when present else hidden, no fabricated placeholder text for missing fields beyond a neutral note for redacted past bookings ("Contact details are only shown while a booking is confirmed").
- **PATTERN**: plan 09 `HostRequestDetailView` extras; plan 06 `BookingContactSection`.
- **GOTCHA**: Host detail for pending bookings from history must not show Accept/Decline here unless plan 09's action bar is reused — keep history detail read-only; pending items in Upcoming link to the Inbox request (`HostInboxRoute`) via a "Respond in Inbox" button (only for host role).
- **VALIDATE**: build

### UPDATE Features/HostInbox/HostInboxView.swift
- **IMPLEMENT**: Toolbar item "History" → pushes `BookingHistoryView(role: .host)` (preselect `.host` for `both` users).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE Features/BookingHistory/BookingHistoryEntry.swift
- **IMPLEMENT**: `BookingHistoryEntry.view(for user: User, environment:) -> some View` — the single entry point plan 13 embeds in Profile ("Booking history" row → push). Default role: driver for `.driver`, host for `.host`, driver for `.both` with the picker visible.
- **PATTERN**: plan 13 owns the Profile screen; this plan provides only the destination.
- **VALIDATE**: build; plan 13 later validates navigation.

### UPDATE Localizable.xcstrings
- **IMPLEMENT**: Tab titles, role labels, empty copy, "Payment (as listed by host)", redaction note, a11y strings.
- **VALIDATE**: build

### CREATE tests and fixtures
- **IMPLEMENT**: see below; fixture `bookings-history-mixed.json` with one booking per status, a confirmed-ended, a pending-expired, and an in-progress confirmed, across 3 pages.
- **VALIDATE**: `TEST`

---

## TESTING STRATEGY

### Unit Tests (Swift Testing)
- **BookingHistoryFilterTests** (table-driven, injected `now`): every status × {future, in progress, ended} lands in exactly one tab (partition property test over a generated matrix incl. `.unknown`); boundaries `end == now`, `start == now`; sort orders (upcoming asc, past/cancelled desc; equal start → stable by `createdAt`); DST week booking classification; declined and cancelled both under Cancelled; driver-role vs host-role irrelevance of the predicate.
- **BookingHistoryViewModelTests**: default tab Upcoming; `select(tab:)` swaps filter without refetching; role picker only for `.both`; `.driver` user never queries `role=host` (assert on fake service call log); switching role keeps each list's data; auto-fill loads extra pages until `minimumVisible` or exhausted, stops at 5 pages, ignores a stale response after a tab switch, stops when a page adds no new IDs; empty tab with `hasMore` shows loading rather than empty; offline shows cached rows and disables pagination; refresh keeps data; recreated on role change; `reset()` clears; cache page-1 replace + prune to 200.
- **Detail/privacy**: host detail for a completed fixture shows driver name/time/total and no phone/address/payment; for a confirmed fixture (contract example) shows driver phone and payment text; a pending fixture that (incorrectly) contains `driver_phone` renders none.
- **Regression**: plan 06 tests still pass with the default `.all` filter (`BookingsListViewModelTests`, `BookingDetailViewModelTests`).

### Edge Cases
Very long history (pagination memory: rows use lightweight value types), bookings crossing midnight or DST, device outside `America/New_York` (zone abbreviation shown), booking that changes status between list and detail (detail refresh wins; list `apply` upsert), offline cold start, both roles empty, role change while screen open, VoiceOver row label includes status + counterparty + time + total, Dynamic Type XXL, dark mode.

## VALIDATION COMMANDS (from `iOS/`)

### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`
### Level 3: Integration
`StubURLProtocol` scenario: `bookings-history-mixed.json` pages → tab switching → detail refresh with status change.
### Level 4: Manual
Account with mixed bookings (or seeded API): verify each tab, role picker for `both`, pull-to-refresh, airplane mode cached view, host detail contents, VoiceOver traversal, XXL text; confirm no address/phone in cached store.

## OPEN QUESTIONS

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | PRD asks for "payment method used" in host detail; payments are off-platform and the contract redacts `payment_method_text` on non-confirmed bookings. Show host's listed text only while confirmed, or have the API retain it on completed bookings? | PRD §4.3 vs contract | Assumed "as listed", confirmed only |
| 2 | Driver phone for completed bookings is redacted by contract; host history detail can't show it after completion. Acceptable (privacy) or retain for N days? | Contract | Assumed acceptable |
| 3 | Who moves `confirmed → completed`, and are unanswered pending requests auto-declined? Until decided, ended confirmed/pending items sit in Past with their raw status. | Contract, PRD §8 #2 | Assumed Past + raw badge |
| 4 | Should a user who switched from `both` to `driver` still see prior host history? | New | Only current roles |
| 5 | Ordering and a `sort`/multi-`status` query on `GET /bookings` would remove client-side filtering; also `GET /bookings/:id`. | README gap 5 | Client-side for MVP |
| 6 | Cancelled-by-listing-deletion vs by-host indistinguishable (no reason field). | Plan 06 Q6 | Generic copy |
| 7 | PRD §8 #5 cancellation grace period — no driver cancel UI, so history has no cancel action. | PRD §8 | Assumed none |
| 8 | Driver info for hosts depends on embedded `driver` summary (plan 06 Q1) and plan 12 rating summary. | Contract gap | Pending |

## ACCEPTANCE CRITERIA

- [ ] Booking history shows Upcoming / Past / Cancelled tabs mapped per the table; each booking appears in exactly one tab
- [ ] Tapping any booking opens full detail (driver info + time + total + payment text for hosts; standard detail for drivers) using plan 06 components
- [ ] `both` users can switch "As driver / As host"; single-role users see only their role
- [ ] Reachable from Inbox toolbar and exported as the Profile "Booking history" entry for plan 13
- [ ] Pagination with auto-fill, pull-to-refresh, offline cached view, empty/error states
- [ ] Hidden fields never rendered outside confirmed; nothing sensitive cached/logged
- [ ] VoiceOver, 44pt targets, Dynamic Type XXL (no truncated segmented control), status via icon+text
- [ ] All validation commands pass; no regressions to plans 06/09; conventions followed
- [ ] Privacy model upheld (no early exposure of address/host phone)
- [ ] `docs/api-contract.md` updated if endpoints changed (sort/status list/`GET /bookings/:id`)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Acceptance criteria met; open questions recorded with decisions
- [ ] Plan 13 informed of `BookingHistoryEntry` API; plan 12 of the detail extension slots

## NOTES

- **Adds no methods to `BookingService.swift`.** Sequence 05 (`createBooking`) → 06 (`bookings`, `booking(id:)`) → 09 (`respond`) → 10 (none) → 12 (`reportNoShow`).
- Client-side classification keeps one dataset per role and avoids multiple parallel status queries whose pagination cannot be merged reliably.
- Ratings hooks (rate/no-show buttons, rating state) are added by plan 12 through `BookingDetailView`'s `extra` slot and row accessory; this plan leaves the slots empty.
- Default MainActor isolation: `BookingListFilter` and `BookingHistoryTab.filter` predicates are `nonisolated` pure values so they can be tested and used off the main actor.
- Memory: keep only value-type `Booking`s in the list VM; no images in rows; cap cache at 200 rows per owner+role.
