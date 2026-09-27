# Feature: Ratings & No-Show Reporting

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities, and import from the right files. `RatingSummaryView` (plan 04), `BookingServicing` (plan 05/06/09) and booking-detail views (plans 06/10) are owned elsewhere — read their final code first.

**Source:** `docs/prd-v1.md` §4.6 (P1 Post-Booking Rating, P1 No-Show Reporting), §6.3 (Post-Booking Rating Flow), §4.7 (rating/no-show notifications), §8 Q5; `docs/api-contract.md` § Ratings, § Bookings (`POST /bookings/:id/no_show`), § Enums, § Error Format; `iOS/plans/README.md` gaps 7, 8.

## Feature Description

After a booking ends, host and driver each rate the other once (thumbs up/down; if down, issue tags and an optional private note) within a 48-hour window. Hosts can report a no-show 30 minutes after start, which flags the booking, auto-files a negative `no_show` rating (server), and notifies the driver. Drivers see a warning at 3 no-shows and are blocked from requesting bookings at 5. Public profiles show "94% positive · 17 bookings" and, for drivers only, "No-shows: N" (even zero).

## User Story

As a host or driver / I want to rate my counterpart and (as a host) report no-shows / So that the community can trust who they meet and unreliable drivers are held accountable.

## Problem Statement

Off-platform payment and no in-app chat mean trust is the product. Without post-booking ratings and no-show accountability, hosts cannot vet drivers and drivers cannot vet hosts. The contract has the endpoints but the client lacks: rating UI, eligibility logic (booking objects don't say whether the window is open or whether the caller already rated), a "driver arrived" signal, and any way to surface warning/suspended states.

## Solution Statement

- `Features/Ratings/` owns `RatingView`/`RatingViewModel` (sheet), issue-tag pickers, `BookingRatingActionView` (embeddable entry point for booking detail), `NoShowPromptView`/`NoShowReportViewModel`, driver-standing UI (`DriverStandingStore`, `NoShowWarningBanner`, `SuspendedNotice`). `Services/RatingService.swift` owns `RatingServicing`.
- Eligibility computed client-side from `Booking` timestamps with **optional server fields** (`can_rate`, `rated_by_me`, `rating_window_ends_at`) preferred when present; the server remains authoritative (403 `rating_window_closed`, duplicates handled).
- Reuse `RatingSummaryView` from plan 04 for the public display; extend it only if it lacks the driver no-shows line.

## Requirements & Acceptance Criteria

Verbatim PRD §4.6:
- "48 hours after booking end time, both host and driver receive a push notification: 'How was your experience with [Name]?'"
- "Rating UI: thumbs up or thumbs down"; "If thumbs down: multi-select issue tags displayed"
- "Optional private free-text note (internal use only, never displayed publicly)"; "Rating window closes automatically after 48 hours"
- Tags — Driver (rated by host): `no_show`, `late_arrival`, `didnt_pay`, `left_mess`, `rude_behavior`. Host (rated by driver): `spot_occupied`, `misrepresented`, `host_unreachable`, `access_blocked`, `rude_behavior`, `false_listing`.
- Public: "User profile: '94% positive · 17 bookings'"; "Driver profile only: 'No-shows: 0' (shown even when zero — zero is a positive trust signal)"; "Specific negative tags are never shown publicly".
- No-show: "30 minutes after booking start time, if driver hasn't been marked as arrived, host sees prompt: 'Driver hasn't shown up?'"; "Tapping it marks booking `noShow: true` and auto-submits a negative rating with the `no_show` tag"; "Driver receives notification that no-show was reported"; "Thresholds: 3 no-shows → in-app warning; 5 no-shows → booking privileges suspended".
- §6.3: notification -> tap -> rating screen -> thumbs -> (down) tags -> optional note -> submit -> stats updated -> visible on profile.

Contract: `POST /ratings { rating: { booking_id, score: 1|-1, tags: [], note } }` (tags only when score -1; 201 returns rating); errors 403 `rating_window_closed`; each party once per booking; caller must be host or driver; booking `completed`, or `confirmed` with `end_time` past. `GET /users/:id/ratings` -> `{ user_id, positive_pct, rating_count, no_show_count }`. `POST /bookings/:id/no_show` (empty body; 200 booking with `no_show: true`; available 30 min after `start_time`).

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium-High
**Platforms**: iOS (Api: extra booking fields, arrived marker, suspension error code)
**Primary Systems Affected**: `Features/Ratings/`, `Services/RatingService.swift`, `BookingServicing`, `Models/Booking.swift`, booking detail (06/10), inbox (09), spot detail/profile (04/13), request booking (05), `AppRouter`
**Dependencies**: none external

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `iOS/plans/01-foundation.md` "CREATE Models/*" (`Rating`, `PublicRatingSummary`, `DriverIssueTag`, `HostIssueTag`, `RatingScore`), "CREATE Core/Networking/APIError.swift" (`.forbidden(code:)`, `.conflict(code:message:)`, `.validation`), `AppRouter`, `SessionStore.update(user:)`.
- `iOS/plans/04-spot-detail.md` — `RatingSummaryView` signature and host trust block.
- `iOS/plans/05-request-booking.md` — `BookingServicing` creation, submit button (suspended-state hook).
- `iOS/plans/06-driver-bookings.md`, `10-booking-history.md` — booking detail views; where the rating action slot goes.
- `iOS/plans/09-host-booking-inbox.md` — request card shows driver summary; host confirmed list.
- `iOS/plans/11-push-notifications.md` — `DeepLink.rate` / `.noShowPrompt` routing.
- `iOS/plans/13-profile-and-settings.md` — own profile shows summary and no-shows.

### New Files to Create
```
iOS/Spotique/Services/RatingService.swift                 RatingServicing + LiveRatingService
iOS/Spotique/Features/Ratings/RatingRoute.swift           RatingRoute.rate(bookingID)
iOS/Spotique/Features/Ratings/RatingView.swift            thumbs, tags, note, submit
iOS/Spotique/Features/Ratings/RatingViewModel.swift
iOS/Spotique/Features/Ratings/RatingSheetLoader.swift     resolves booking by id then shows RatingView (push entry)
iOS/Spotique/Features/Ratings/IssueTag+Display.swift      localized labels, party mapping
iOS/Spotique/Features/Ratings/RatingEligibility.swift     pure functions: window, can-rate
iOS/Spotique/Features/Ratings/BookingRatingActionView.swift   embeddable "Rate" row for booking detail
iOS/Spotique/Features/Ratings/RatedBookingsStore.swift    local fallback: rated booking IDs
iOS/Spotique/Features/Ratings/NoShowPromptView.swift / NoShowReportViewModel.swift
iOS/Spotique/Features/Ratings/DriverStandingStore.swift   good/warning/suspended
iOS/Spotique/Features/Ratings/NoShowWarningBanner.swift / SuspendedNotice.swift
iOS/SpotiqueTests/Fakes/{FakeRatingService,FakeBookingService+NoShow}.swift
iOS/SpotiqueTests/Fixtures/{rating-created.json,rating-summary.json,booking-no-show.json,error-rating-window-closed.json}
iOS/SpotiqueTests/{RatingViewModelTests,RatingEligibilityTests,RatingServiceTests,NoShowReportViewModelTests,DriverStandingStoreTests}.swift
```
UPDATE: `iOS/Spotique/Models/Booking.swift` (optional fields), `Services/BookingService.swift` (`reportNoShow`), `Core/DesignSystem`-adjacent `RatingSummaryView` (plan 04 file), `App/AppRouter.swift`, `App/AppEnvironment.swift`, `Localizable.xcstrings`.

### Documentation — READ BEFORE IMPLEMENTING
- `docs/api-contract.md` § Ratings, § `POST /bookings/:id/no_show`, § Enums, § Error Format.
- [Human Interface Guidelines: Toggles / Buttons](https://developer.apple.com/design/human-interface-guidelines/toggles), [Accessibility traits](https://developer.apple.com/documentation/swiftui/view/accessibilitytraits(_:)) — selected trait for thumbs/tag chips.
- [confirmationDialog](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)) for irreversible no-show.

### Skills to Apply
`mvvm-architecture`, `swiftui-development`, `spotique-brand-ui`, `ios-api-client` (service/tests), `ios-security-review` (note is private, never logged), `swift-concurrency-6-2`.

### Patterns to Follow
ViewModel: `@Observable @MainActor final class RatingViewModel` with `enum State { idle, submitting, submitted(Rating), closed, alreadyRated, failed(APIError) }`. Service: `protocol RatingServicing: Sendable` + `struct LiveRatingService(apiClient:)`. Injectable clock `now: () -> Date` for window/prompt tests (no `sleep`). Strings via `String(localized:)`/`LocalizedStringResource`.

---

## PRIVACY & SECURITY

- Private note: sent only in `POST /ratings`, never displayed, never logged, never cached; keep it in the ViewModel only (drop on dismiss). UI text: "Only Spotique can see this note. It is never shown on profiles."
- Negative tags never appear on any public/counterpart-facing screen; the client only ever receives aggregates (`GET /users/:id/ratings`) — the ratee never sees who tagged what. Tag labels used only in the submit flow.
- Rating screen shows counterpart **first name only**; no phone/address. A confirmed booking's address/phone (already legitimately held) must not be copied into rating state.
- No-show and rating actions are authorized server-side (caller is host/driver on booking; 30-min gate; 48-h window); the client gates are UX only. Never trust the device clock for correctness — treat 403/422 as truth and refresh.
- Suspended state must come from the server (403 code); the client must not rely on `noShowCount >= 5` alone to *unblock*, only to pre-empt.
- Summary caches are in-memory only (5 min), cleared on sign-out. `RatedBookingsStore` stores booking IDs only, cleared on sign-out.
- Payloads/deep links (`rating_open`, `no_show_reported`) are untrusted; booking loaded through the API before use (plan 11).

## IMPLEMENTATION PLAN

### Phase 1: Foundation — models (optional booking fields), tag display, eligibility, `RatingServicing`, fixtures
### Phase 2: Core — `RatingViewModel/View`, no-show reporting, `DriverStandingStore`, summary line
### Phase 3: Integration — booking-detail hook (06/10), inbox prompt (09), request-booking gating (05), push routing (11), profile (13), `AppRouter.ratingSheet`
### Phase 4: Testing & validation

### Design decisions
1. **Notification timing contradiction (PRD §4.6 / §4.7 / §6.3)**: the PRD sends "How was your experience" **48 h after end** and closes the window **48 h after end** — the prompt would arrive exactly as the window closes. **Assumption**: the window is `[end_time, end_time + 48h]` (matches the contract); the client allows rating any time in that span from booking detail; the `rating_open` push should be sent shortly after `end_time` (recommend +1 h, optional reminder +24 h). The client is agnostic to send time; it handles a late tap via 403 `rating_window_closed`.
2. **Eligibility** (`RatingEligibility.state(booking:, myUserID:, now:, ratedLocally:)` -> `.eligible(closesAt) | .alreadyRated | .windowClosed | .notYet | .notRatable`): prefer server fields `canRate`, `ratedByMe`, `ratingWindowEndsAt` if non-nil; else `status == .completed || (status == .confirmed && endTime < now)`, `now < endTime + 48h`, not in `RatedBookingsStore`. Declined/cancelled/pending -> `.notRatable`. A booking with `noShow == true`: host's rating already auto-filed (server) -> host `.alreadyRated`; the driver may still rate the host.
3. **Who is being rated**: `booking.hostId == myUserID` -> I am host, rating the **driver** (driver tag set); else I am the driver rating the **host** (host tag set).
4. **Counterpart name**: Booking has no name fields (contract gap). Push copy supplies it server-side; in-app use the name known to the caller's screen (listing `hostDisplayName` for drivers; inbox card driver display name for hosts — plan 09) passed into `RatingView`; fallback "your host" / "your driver". Request `driver_display_name`/`counterparty_name` on Booking.

---

## STEP-BY-STEP TASKS

Run from `iOS/`. Suite command: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/<Suite>`.

### UPDATE Models/Booking.swift (optional server fields) and Models/Enums.swift
- **IMPLEMENT**: add optional `canRate: Bool?`, `ratedByMe: Bool?`, `ratingWindowEndsAt: Date?`, `arrivedAt: Date?`, `counterpartyName: String?` (all `nil` when absent; **proposed** server fields — README gap 7/8). Ensure `DriverIssueTag`/`HostIssueTag` are `CaseIterable` with unknown-tolerant decoding; `nonisolated`.
- **PATTERN**: optional hidden-field pattern in plan 01 "CREATE Models/*".
- **GOTCHA**: `.convertFromSnakeCase` maps `rating_window_ends_at` -> `ratingWindowEndsAt`. Missing keys must not fail decoding (older fixtures).
- **VALIDATE**: `... -only-testing:SpotiqueTests/ModelDecodingTests` (booking with and without new fields).

### CREATE Services/RatingService.swift
- **IMPLEMENT**: `protocol RatingServicing: Sendable { func submit(bookingID: String, score: RatingScore, tags: [String], note: String?) async throws -> Rating; func summary(userID: String) async throws -> PublicRatingSummary }`. `submit` sends `{ "rating": { "booking_id", "score", "tags", "note" } }` via the encoder (`convertToSnakeCase`); omit `note` when blank; `tags` empty for score 1. `summary` -> `GET /users/:id/ratings` (`requiresAuth`).
- **GOTCHA**: `PublicRatingSummary` keys `positive_pct` -> `positivePct` (plan 01 model). 403 `rating_window_closed` arrives as `.forbidden(code: "rating_window_closed")`; duplicates: contract silent — map `.conflict(code:_)`/422 to `alreadyRated` (open question 3).
- **VALIDATE**: `... -only-testing:SpotiqueTests/RatingServiceTests` (request body per score, empty-note omitted, 201 decode, 403 window closed, 404, summary decode).

### CREATE Features/Ratings/IssueTag+Display.swift
- **IMPLEMENT**: `protocol RatingIssueTag: CaseIterable, Identifiable { var localizedTitle: String { get } var symbolName: String { get } }` for both tag enums. Human labels (String Catalog keys `rating.tag.<raw>`): no_show "Didn't show up", late_arrival "Arrived late", didnt_pay "Didn't pay", left_mess "Left a mess", rude_behavior "Rude behavior", spot_occupied "Spot was occupied", misrepresented "Spot wasn't as described", host_unreachable "Host was unreachable", access_blocked "Access was blocked", false_listing "False listing". `RatingPartyTags.tags(forRatedParty: .driver|.host) -> [AnyIssueTag]` (raw string + title + symbol).
- **GOTCHA**: `rude_behavior` exists in both sets — separate enums avoid collisions; wire value is the raw string only. Every tag has an SF Symbol so selection is not color-only.
- **VALIDATE**: `... -only-testing:SpotiqueTests/RatingViewModelTests` (each set matches contract exactly; every raw has catalog key).

### CREATE Features/Ratings/RatingEligibility.swift, RatedBookingsStore.swift
- **IMPLEMENT**: pure eligibility per Design decision 2; `RatedBookingsStore` (UserDefaults `Set<String>` keyed by user id; `markRated`, `contains`, `clear()` on sign-out via plan 11's sign-out hook).
- **VALIDATE**: `... -only-testing:SpotiqueTests/RatingEligibilityTests` (matrix: completed/confirmed-ended/confirmed-future/declined; before end; at end+48h boundary (closed at exactly 48h); server fields override; local rated; no-show host).

### CREATE Features/Ratings/RatingViewModel.swift
- **IMPLEMENT**: `init(booking:, myUserID:, counterpartName:, ratingService:, ratedStore:, now:)`. Observable: `state`, `score: RatingScore?`, `selectedTags: Set<String>`, `note: String` (cap 500, `noteRemaining`), computed `ratedParty`, `availableTags`, `canSubmit` (score chosen, not submitting), `windowClosesAt`. Actions: `select(score)` (switching to up clears tags), `toggle(tag)` (only when down), `submit()` (guard re-entry; on success `markRated`, state `.submitted`; `.forbidden("rating_window_closed")` -> `.closed`; duplicate -> `.alreadyRated` treated as success-ish message; offline -> retryable failed; other -> failed with `errorDescription`). `onSubmitted: (Rating) -> Void` callback for the presenter to refresh.
- **GOTCHA**: never log `note`; never persist draft. Use `now()` injection.
- **VALIDATE**: `... -only-testing:SpotiqueTests/RatingViewModelTests` (tags cleared on up, no tags sent with up, host vs driver sets, submit success/closed/duplicate/offline/validation, double-tap guard, note cap).

### CREATE Features/Ratings/RatingView.swift and IssueTagPicker
- **IMPLEMENT**: presented as a sheet with `NavigationStack`. Title "How was your experience with {Name}?" Two large `ThumbButton`s (up/down, min 100x64, icon + text "Thumbs up"/"Thumbs down", selected state uses fill + checkmark + `.isSelected` trait). If down: animated (respect Reduce Motion) `IssueTagPicker` in a wrapping flow layout of toggle chips (min 44pt height, icon + title, `.isSelected`), footnote "Select all that apply". Optional `TextEditor` note with placeholder "Add a private note (optional)" and helper text about privacy, counter. Footer "Rating closes {date}". `PrimaryButton("Submit")` loading state. Success state: checkmark + "Thanks for your feedback" then auto-dismiss (~0.8 s per ios-performance note). `.closed`: `EmptyStateView` "The rating window has closed" (48 hours after the booking). `.alreadyRated`: "You've already rated this booking."
- **Accessibility**: thumbs = buttons "Thumbs up, rating for {Name}" with value selected/not selected; focus moves to the tag group when it appears (`@AccessibilityFocusState`); Dynamic Type through accessibilityXXXL (chips wrap, sheet scrolls); Cancel toolbar button; keyboard avoidance for note.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build` + previews (up, down+tags, submitting, closed, already rated, XXXL, dark).

### CREATE Features/Ratings/BookingRatingActionView.swift  (hook for plans 06/10)
- **Exact hook plans 06/10 must expose**: in the booking-detail screen (driver detail in 06; shared detail for all users in 10) add, for bookings whose status is `confirmed` (ended) or `completed`, a section that embeds `BookingRatingActionView(booking: Booking, myUserID: String, counterpartName: String?, onRated: () -> Void)` and passes a refresh closure that reloads the booking. The view renders by `RatingEligibility`: `.eligible` -> prominent "Rate {Name}" button + "Closes in Xh" caption, presenting `RatingView` via its own `.sheet`; `.alreadyRated` -> "You rated {Name}" (thumb icon + text, no tags); `.windowClosed` -> caption "Rating closed"; `.notYet/.notRatable` -> renders nothing. The host must not build rating UI or eligibility logic itself. Also expose the same view in plan 09 host confirmed/past list rows via `compact: true` (chip-sized).
- **VALIDATE**: build + previews for each eligibility state.

### CREATE Features/Ratings/RatingSheetLoader.swift, RatingRoute.swift and UPDATE App/AppRouter.swift
- **IMPLEMENT**: `enum RatingRoute: Hashable, Identifiable { case rate(bookingID: String) }`. Add `AppRouter.ratingSheet: RatingRoute?` presented from `MainTabView` with `.sheet(item:)`; plan 11's router sets it for `DeepLink.rate`. `RatingSheetLoader` resolves the booking (no `GET /bookings/:id` — README gap 5 — falls back to `BookingServicing.list` and finds by id), then shows `RatingView`; 404/not found -> `EmptyStateView` "This booking is no longer available"; loading skeleton.
- **VALIDATE**: `... -only-testing:SpotiqueTests/AppRouterTests`.

### UPDATE Services/BookingService.swift — `reportNoShow`
- **IMPLEMENT**: add `func reportNoShow(bookingID: String) async throws -> Booking` to `BookingServicing` (defined plan 05, extended 06/09): `POST /bookings/:id/no_show`, empty body, `requiresAuth`; update `FakeBookingService`.
- **GOTCHA**: coordinate with plans 05/06/09 to avoid duplicate protocol edits; only this method is plan 12's.
- **VALIDATE**: `... -only-testing:SpotiqueTests/BookingServiceTests` (or `RatingServiceTests` if none) — POST path, decode `no_show: true`, 403/422 too-early mapped.

### CREATE Features/Ratings/NoShowReportViewModel.swift, NoShowPromptView.swift
- **IMPLEMENT**: host-only prompt "Driver hasn't shown up?" shown when `role == host on booking`, `status == .confirmed`, `!noShow`, `arrivedAt == nil`, not locally dismissed as arrived, and `now >= startTime + 30 min` (visible until `endTime + 48h`, so late reports remain possible; open question 4). Two actions: primary "Report no-show" (`confirmationDialog`: "Report {Name} as a no-show? They'll receive a negative rating and be notified. This can't be undone.") and secondary "Driver is here" which (a) calls `POST /bookings/:id/arrived` **if the API exists** (proposed; hidden behind `BookingServicing.markArrived` protocol default that throws `.notSupported`), else (b) stores the booking id in a local `ArrivedDismissalStore` so the prompt stops. After success: booking updated (`noShow = true`), prompt replaced by "No-show reported" status (icon + text), rating action for the host becomes `.alreadyRated`. Errors: too early (403/422 code unknown) -> "You can report a no-show 30 minutes after the start time." and refresh; offline -> retry.
- **Placement**: `NoShowPromptView` embeds at the top of the host's booking detail (plans 09/10) and as a compact row in the host's confirmed bookings list; also the target of `DeepLink.noShowPrompt` (opens that booking detail scrolled to the prompt).
- **A11y**: prompt is a single container with `.accessibilityElement(children: .contain)`; destructive role on report; announces result via `AccessibilityNotification.Announcement`.
- **VALIDATE**: `... -only-testing:SpotiqueTests/NoShowReportViewModelTests` (visibility matrix incl. exactly +30 min boundary, arrived dismissal, success, too-early, offline retry, double-tap guard).

### CREATE Features/Ratings/DriverStandingStore.swift, NoShowWarningBanner.swift, SuspendedNotice.swift
- **IMPLEMENT**: `@Observable @MainActor final class DriverStandingStore` (in `AppEnvironment`) with `standing: DriverStanding = .good | .warning(noShows: Int) | .suspended`. Inputs: `SessionStore.currentUser?.noShowCount` (role driver/both), refreshed via `RatingServicing.summary(userID: me)` on app foreground, when My Bookings loads, on `no_show_reported` push, and after the booking request 403; plus server signal `APIError.forbidden(code: "booking_privileges_suspended")` (**proposed code**, open question 5) -> `.suspended` immediately. Rules: `>= 5` suspended; `>= 3` warning; else good. Updates `SessionStore.update(user:)` with the refreshed count. `NoShowWarningBanner`: "You have {n} no-shows. At 5, your booking privileges will be suspended." (pluralized, warning icon + text, not dismissible for the session but collapsible) shown at the top of My Bookings (06) and above the submit button in Request Booking (05). `SuspendedNotice`: "Booking is paused. Your account has reached 5 reported no-shows, so you can't request new bookings right now. Contact support to learn more." (support contact TBD, open question 6); plan 05 disables "Request booking" when `standing == .suspended` with this explanation adjacent (not just a greyed button — explain why, VoiceOver hint); plan 03 spot preview cards remain browsable. Hosts unaffected.
- **GOTCHA**: warning also on `.suspended`? Show `SuspendedNotice` only. If the count later decreases (server clears), refresh removes the state; never persist suspension locally.
- **VALIDATE**: `... -only-testing:SpotiqueTests/DriverStandingStoreTests` (2/3/4/5 boundaries, role host ignored, 403 code flips to suspended, refresh clears, sign-out reset).

### UPDATE RatingSummaryView (plan 04) and public display integration
- **IMPLEMENT**: verify the component renders "94% positive · 17 bookings" (`positivePct`, `ratingCount`; singular "1 booking"); `ratingCount == 0` -> "New · No ratings yet" (PRD silent; open question 7); add an optional `noShowCount: Int?` parameter that, when non-nil, renders "No-shows: N" on a second line including 0 — pass it **only** for drivers (plan 09 inbox card & driver profile via plan 13; never on host surfaces such as plan 04 spot detail). Accessibility label: "94 percent positive, 17 bookings. 0 no-shows." A `RatingSummaryLoader` caches `summary(userID:)` for 5 min in memory.
- **GOTCHA**: `rating_count` is "ratings" in the contract but "bookings" in PRD copy — assumed equal (open question 8). Never render tags or notes anywhere.
- **VALIDATE**: `... -only-testing:SpotiqueTests/RatingViewModelTests` (formatting cases) + previews.

### UPDATE App/AppEnvironment.swift, Localizable.xcstrings
- **IMPLEMENT**: add `ratingService`, `driverStandingStore`; extract all strings above (plural variations for no-shows/bookings).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`.

### CREATE integration wiring notes verified by tests
- **IMPLEMENT**: push routing check: `DeepLink.rate(id)` -> `AppRouter.ratingSheet`; `DeepLink.noShowPrompt(id)` -> host booking detail; `no_show_reported` -> refresh `DriverStandingStore`.
- **VALIDATE**: `... -only-testing:SpotiqueTests/NotificationRouterTests` (after plan 11).

---

## TESTING STRATEGY

### Unit Tests
Swift Testing; `FakeRatingService`, `FakeBookingService`, injected `now`. Cover per-task suites above; fixtures copied from contract (`rating-created.json`, `rating-summary.json`).

### Integration / UI Tests
XCUITest with fake environment: rate up (no tags shown), rate down (tags appear, submit disabled until a thumb chosen), closed window state, no-show flow with confirmation dialog, suspended driver sees disabled request button with explanation. `performAccessibilityAudit()` on rating sheet (plan 14).

### Edge Cases
Rating at exactly +48 h; device clock skew (server 403 wins); both parties rate concurrently; duplicate submit after a timeout (unknown outcome -> refetch booking flags); tag selected then thumb switched to up; very long note; app killed mid-submit; host reports no-show, then driver arrives (irreversible; needs support path); booking becomes `completed` between prompt and tap; host with role `both` rating as driver on another booking (role derived per booking); push tap for a booking already rated; offline submit shows error, no queued retry (PRD §7.4); cancelled bookings never ratable; Dynamic Type XXXL; VoiceOver order thumbs -> tags -> note -> submit.

## VALIDATION COMMANDS
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`
### Level 3: Integration
`... test -only-testing:SpotiqueUITests/RatingFlowUITests` (with stubbed environment launch argument from plan 01/14).
### Level 4: Manual
`xcrun simctl push booted com.actionman.Spotique SpotiqueTests/Fixtures/push/rating_open.apns` and `no_show_prompt.apns` (plan 11) -> correct screens; VoiceOver pass; Dynamic Type XXXL; verify `grep -rn "note" Spotique/Features/Ratings | grep -i "Log\."` returns nothing.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Notification "48h after end" vs window "closes 48h after end" — when should `rating_open` be sent? | PRD §4.6/§4.7/§6.3 | Assumed: window from end; push shortly after end (+1 h), reminder +24 h |
| 2 | Booking lacks `can_rate`/`rated_by_me`/`rating_window_ends_at` and counterpart name | README gap 7 | Optional fields proposed; client computes fallback |
| 3 | Duplicate-rating error code/status (contract: "each party once") | Contract | Assumed 409/422 -> already rated |
| 4 | Upper bound for no-show reporting (contract: available 30 min after start; until when?) | Contract | Assumed until end+48 h; server authoritative |
| 5 | Suspended-driver error code (contract only says "suspended") | Contract § no_show | Proposed 403 `booking_privileges_suspended` on `POST /bookings` |
| 6 | Suspension duration/appeal/support contact | PRD §4.6 | Undefined; permanent assumed, placeholder copy |
| 7 | Empty summary copy for 0 ratings | PRD | "New · No ratings yet" assumed |
| 8 | `rating_count` vs "bookings" in display | PRD vs Contract | Treated as equal |
| 9 | "Driver arrived" marking has no endpoint/UI | PRD §4.6, README gap 8 | Proposed `POST /bookings/:id/arrived` (host) or arrival auto-detected; interim local dismissal |
| 10 | Grace period for driver cancelling a confirmed booking | PRD §8 Q5 | Not implemented; cancellations never count as no-shows client-side; cancelled bookings are not ratable |
| 11 | Who moves a booking to `completed`? Rating requires `completed` or ended `confirmed` | Contract | Client treats ended confirmed as ratable |
| 12 | Is a no-show report reversible (dispute)? | PRD | Assumed irreversible; confirmation dialog |
| 13 | PRD says decline -> "cancelled"; contract says `declined` | PRD §4.3 vs Contract | Follow contract |

## ACCEPTANCE CRITERIA
- [ ] Thumbs up/down; tags only after thumbs down with the exact per-party sets and localized labels
- [ ] Optional private note, never shown or logged; capped
- [ ] Rating possible from booking detail hook and from `rating_open` push; closed window and duplicates handled gracefully
- [ ] Host no-show prompt appears from +30 min for confirmed bookings, reports via `POST /bookings/:id/no_show`, and updates UI
- [ ] Driver warning at >= 3, suspended state at >= 5 (and on server 403) disables requests with explanation
- [ ] Public display "94% positive · 17 bookings"; driver-only "No-shows: N" incl. zero; no tags public
- [ ] Accessibility: VoiceOver labels/traits, Dynamic Type XXXL, 44pt targets, non-color selection
- [ ] All validation commands pass; no regressions; conventions followed
- [ ] Privacy model upheld (no address/phone in rating flows or notifications)
- [ ] `docs/api-contract.md` updated for new booking fields/arrived/suspension code if adopted

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Hooks confirmed with plans 04, 05, 06, 09, 10, 11, 13 owners
- [ ] Open questions recorded with decisions

## NOTES
- Client-side gates are UX conveniences; the server enforces window, once-per-party, 30-min gate, and suspension.
- Host's automatic `no_show` rating means the host is never asked to rate that booking again.
- Ratings in MVP are one-shot: no editing/deleting, no offline queue.
- Under default MainActor isolation, `RatingEligibility` and tag types are pure `nonisolated` helpers for easy testing.
- Cancellation grace (PRD Q5) is intentionally out of scope; no driver-cancel UI exists in MVP (README).
