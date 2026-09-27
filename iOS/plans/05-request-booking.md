# Feature: Request Booking (Time Selection, Total, Confirmation, Submit, Conflict Handling)

> Validate documentation, codebase patterns, and task sanity before implementing. Depends on plan 04 (Spot Detail, `SpotDetailContext`, `RatingSummaryView`, `ListingAvailability` display copy) and plan 03 (`TimeWindow`, `ListingAvailability`, `ExploreRouter`, `Calendar.spotique`). Shared types come from plan 01; reference, do not redefine.

**Source:** `docs/prd-v1.md` §4.4 "P0 — Request Booking", §6.2 steps 2-4, §7.1 (submission < 2 s), §7.4 (offline), §8 #2/#3; `docs/api-contract.md` > `POST /bookings`, "Enums", "Error Format"; `iOS/plans/README.md`.

## Feature Description

The driver picks a date, start time, and end time for a spot, sees the calculated total (rate x hours), reviews a confirmation summary with the payment reminder, and submits. The app creates a `pending` booking, shows a success state, and moves the driver to the Bookings tab (plan 06). Conflicts, validation failures, offline, and ambiguous timeouts each have explicit handling.

## User Story

As a driver, I want to request a specific time window at a spot and see exactly what it will cost, so that I can secure parking with clear expectations.

## Problem Statement

Booking requests are the core transaction. The client must prevent invalid requests, be transparent about the cost and off-platform payment, handle races with other drivers (409), and never leave the driver unsure whether a request went through.

## Solution Statement

Two pushed routes with separate ViewModels: `RequestBookingView` (selection + validation, produces a `BookingDraft`) and `ConfirmationSummaryView` (review + submit, owns the network call). A pure `BookingPricing` computes integer-cent totals; `TimeWindow+Validation` holds the rules. `BookingServicing.createBooking(...)` wraps `POST /bookings`. The server is authoritative for overlap, future start, and duration; the client mirrors those rules for immediate feedback.

## Requirements & Acceptance Criteria

PRD §4.4 Request Booking (verbatim):
- Driver selects date, start time, end time
- App calculates and displays total cost (rate × hours)
- Confirmation screen summarizes details and shows payment reminder: "You'll pay the host directly in cash, Venmo, or Zelle on arrival."

Acceptance criteria (verbatim):
- Can only request future time slots
- Minimum booking duration: 1 hour; maximum: 8 hours
- Overlap check runs against all pending + confirmed bookings before submission
- On conflict: "This spot is already booked for that time. Please choose a different window."
- On success: Firestore booking created as "pending"; host push notification fired  *(PRD wording is stale: REST `POST /bookings` returns `status: "pending"`; the push is a server side effect, plan 11)*

Contract `POST /bookings`: body `{"booking":{"listing_id","start_time","end_time"}}` (ISO 8601 UTC); 201 -> `{"data": Booking}` with `status: "pending"`, `total_cents`; validations: start in future, 1-8 h, no overlap with pending/confirmed -> 409 `booking_conflict`. §7.1: submission completes within 2 seconds. §7.4: "Booking submission requires active connection; a clear offline error is shown."

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium
**Platforms**: iOS (Api: `POST /bookings` must exist first; use fakes until then)
**Primary Systems Affected**: `Features/RequestBooking/`, `Services/BookingService.swift`, `Models/BookingPricing.swift`, `Models/TimeWindow+Validation.swift`, `ExploreRoute`, `AppRouter`, `AppEnvironment`
**Dependencies**: None external

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- Plan 03: `Models/{TimeWindow,ListingAvailability}.swift`, `Core/Extensions/Calendar+Extensions.swift`, `Features/Map/{ExploreRoute,WhenFilterViewModel}.swift` (15-minute slot generation to reuse), `Services/ListingService.swift` (service style).
- Plan 04: `Features/SpotDetail/{SpotDetailContext,RequestButtonState,DayAvailabilityView}.swift`.
- Plan 01: `Models/Booking.swift`, `Core/Networking/{APIClient,APIError}.swift` (`.conflict(code:message:)`, `.validation`, `.offline`, `.forbidden`, `.rateLimited`), `App/AppRouter.swift` (`selectedTab`, `pendingDeepLink`), `Core/DesignSystem/Components/{PrimaryButton,StatusBadge,ErrorBanner}.swift`, `Fixtures/{booking-pending,error-conflict,error-validation}.json`.
- `docs/api-contract.md` lines 284-324, 481-502.

### New Files to Create
```
iOS/Spotique/Features/RequestBooking/RequestBookingView.swift            selection screen
iOS/Spotique/Features/RequestBooking/RequestBookingViewModel.swift
iOS/Spotique/Features/RequestBooking/BookingDraft.swift                  Hashable {listing, window, totalCents}
iOS/Spotique/Features/RequestBooking/ConfirmationSummaryView.swift       review + submit + success state
iOS/Spotique/Features/RequestBooking/ConfirmationSummaryViewModel.swift
iOS/Spotique/Features/RequestBooking/BookingSubmitError.swift            error -> user copy mapping
iOS/Spotique/Models/BookingPricing.swift
iOS/Spotique/Models/TimeWindow+Validation.swift
iOS/Spotique/Services/BookingService.swift                               BookingServicing + LiveBookingService
iOS/SpotiqueTests/{RequestBookingViewModelTests,ConfirmationSummaryViewModelTests,BookingPricingTests,TimeWindowValidationTests,LiveBookingServiceTests}.swift
iOS/SpotiqueTests/Fakes/FakeBookingService.swift
```
Updates: `ExploreRoute` (+`.requestBooking(SpotDetailContext)`, `.bookingConfirmation(BookingDraft)`), `ExploreRouter` (+`conflictedWindow`), `AppEnvironment` (+`bookingService`), plan 04 `SpotDetailViewModel.requestBooking()`, `Localizable.xcstrings`.

### Documentation — READ BEFORE IMPLEMENTING
- `docs/api-contract.md` § Bookings, § Error Format.
- Apple: [DatePicker & timeZone environment](https://developer.apple.com/documentation/swiftui/datepicker), [Date.ISO8601FormatStyle](https://developer.apple.com/documentation/foundation/date/iso8601formatstyle), [Sensory feedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)).

### Skills to Apply
`mvvm-architecture`, `swiftui-development`, `ios-api-client` (error mapping, no retry of non-idempotent POST), `spotique-brand-ui`, `liquid-glass-design` (sticky total bar), `ios-security-review` (logging, phone sharing disclosure), `swift-concurrency-6-2`.

### Patterns to Follow
Plan 03 `MapViewModel` state machine style; plan 01 service pattern (`protocol BookingServicing: Sendable` + `struct LiveBookingService` over `APIClient`, `requiresAuth: true`). Body encoded with explicit ISO 8601 UTC `Z` (no fractional seconds) for `start_time`/`end_time`, and `booking` wrapper key as in the contract.

---

## PRIVACY & SECURITY

- **Before confirmation the driver sees:** `display_address`, host display name, rate, total. Never the full address, host phone, or payment handle. The `Booking` returned at creation contains no `address`/`host_phone` (contract 201 example); the pending state must not display them even if a future API adds them.
- **Driver phone is shared with the host at booking creation** (PRD §7.2, README). Recommended: state this once on the review screen ("Your phone number will be shared with the host so you can coordinate arrival.") — flagged as a product question, not decided.
- Requires an authenticated, profile-complete, **driver/both** account; 403 `forbidden` and `profile_incomplete` are mapped (below). Booking-own-listing is prevented in plan 04 and mapped here from 403.
- No booking details, phone numbers, or times in logs beyond `.private`-interpolated IDs; error bodies are not logged.
- Double-submit protection is client-side only (contract has no idempotency key); see Open Questions.

## IMPLEMENTATION PLAN

### Phase 1: Foundation
`BookingPricing`, `TimeWindow+Validation`, `BookingServicing` + fake + fixtures.
### Phase 2: Core Implementation
`RequestBookingViewModel` + view; `ConfirmationSummaryViewModel` + view (submit, success, errors).
### Phase 3: Integration
Routes, `AppEnvironment`, conflict hand-back to the selection screen, success -> Bookings tab handoff (plan 06), plan 04 button wiring.
### Phase 4: Testing & Validation

---

## STEP-BY-STEP TASKS

### CREATE Models/BookingPricing.swift
- **IMPLEMENT**: `nonisolated enum BookingPricing { static func totalCents(rateCents: Int, window: TimeWindow) -> Int? }` = `rateCents * minutes / 60` using integer minutes (window duration rounded to whole minutes), half-up rounding; returns nil for non-positive duration. `hoursText` helper ("4 hours", "1.5 hours"). Formatting to currency happens in the view with `FormatStyle.Currency`.
- **GOTCHA**: Never use `Double` for money. Slots are 15-minute steps so results are exact multiples of 25 cents for whole-dollar rates. DST: duration is real elapsed time (a 1:30 AM - 3:30 AM window on 2026-11-01 is 3 h; on 2026-03-08 the 1:30-3:30 AM window is 1 h).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/BookingPricingTests`

### CREATE Models/TimeWindow+Validation.swift
- **IMPLEMENT**: `enum BookingWindowIssue: Hashable { startInPast, endNotAfterStart, tooShort, tooLong, spansMidnight, outsideAvailability(DayHours), blockedDate, dayClosed }`; `TimeWindow.issues(now:, listing:) -> [BookingWindowIssue]` using min 1 h (`>= 3600 s`), max 8 h (`<= 28800 s`), `start > now`, single-day check (`crossesLocalMidnight`), and `ListingAvailability.evaluate`. Ordered so the most actionable issue is first. Constants `BookingRules.minDuration`, `.maxDuration`.
- **GOTCHA**: The contract does not state that the server validates availability schedule or blocked dates on `POST /bookings` (Open Question 2); the client blocks them, but the server should too. Compare `now` at both selection and submit time.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/TimeWindowValidationTests` (boundaries 59:59 / 1:00 / 8:00 / 8:00:01, start exactly now, midnight, blocked date, DST dates 2026-03-08 and 2026-11-01)

### CREATE Services/BookingService.swift; UPDATE AppEnvironment
- **IMPLEMENT**: `protocol BookingServicing: Sendable { func createBooking(listingID: String, window: TimeWindow) async throws -> Booking }`; `LiveBookingService` POSTs `/bookings` with `requiresAuth: true`, no automatic retry, decodes `Booking` from the `data` envelope. Plans 06/09/12 extend the protocol (list, respond, noShow). Register `bookingService` in `AppEnvironment` (live + preview fake).
- **PATTERN**: plan 03 `ListingService.swift`; `ios-api-client`.
- **GOTCHA**: Mark `nonisolated`. Encoder must emit `2026-06-01T14:00:00Z` (ISO 8601, UTC, whole seconds) irrespective of `JSONCoding.encoder` defaults; add a body-shape test.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/LiveBookingServiceTests` (request body/path/header, 201 decode, 409 -> `.conflict("booking_conflict")`, 422 -> `.validation` with `start_time` field, 403, 404, 429, offline, cancellation)

### CREATE Features/RequestBooking/BookingDraft.swift, RequestBookingViewModel.swift
- **IMPLEMENT**: `BookingDraft: Hashable {listing: Listing, window: TimeWindow, totalCents: Int}`. `@Observable @MainActor final class RequestBookingViewModel(context: SpotDetailContext, now: @Sendable () -> Date, router)`. State: `date: Date` (NY day), `startSlot`, `endSlot` (15-minute values), initial from `context.window` else next 15-minute slot after now + 1 h duration; `conflictNotice: String?`. Derived: `window: TimeWindow?`, `issues`, `totalCents`, `canContinue`, `inlineMessage` (first issue as localized text, e.g. "Bookings must be between 1 and 8 hours.", "Choose a start time in the future.", "The host isn't available then. Hours: 8:00 AM - 6:00 PM.", "Bookings must start and end on the same day."). Actions: `setDate`, `setStart` (keeps duration if valid), `setEnd`, `continueToReview()` -> `router.path.append(.bookingConfirmation(draft))`, `onAppear()` (reads `router.conflictedWindow`: if equal to current window, shows conflict banner "This spot is already booked for that time. Please choose a different window." and keeps Continue disabled until the window changes).
- **PATTERN**: plan 03 `WhenFilterViewModel` slot generation; `mvvm-architecture`.
- **GOTCHA**: Do not compute a window in a way that changes offsets by 24 h arithmetic (DST). Past start slots for today are excluded from the picker, but `issues` still guards them (clock advances while the screen is open: re-check on `continueToReview()`).
- **VALIDATE**: `... test -only-testing:SpotiqueTests/RequestBookingViewModelTests`

### CREATE Features/RequestBooking/RequestBookingView.swift
- **IMPLEMENT**: Header with photo thumb (`ListingPhotoView`), type, `displayAddress`. Date picker (compact `DatePicker`, `.environment(\.timeZone, .spotique)`, range today...+30 days), start and end time as `Picker`s over 15-minute slots (SwiftUI `DatePicker` has no minute interval). Live summary: "Sat, Jun 1 · 10:00 AM - 2:00 PM ET · 4 hours", rate line "$5.00/hr", **total** "Total $20.00" (updates as pickers change, `contentTransition(.numericText())`). Sticky glass bottom bar with total and `PrimaryButton("Review Request")` (disabled + visible reason text when `issues` non-empty). Also shows host hours for the chosen day inline (reuse `DayAvailabilityView` summary).
- **GOTCHA**: 44 pt targets; Dynamic Type XXL must keep pickers usable (stack vertically); reason text uses icon + text. If the device timezone is not New York show "Times are in New York (ET)".
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; previews (valid, too short, past, conflict banner, XXL).

### CREATE Features/RequestBooking/BookingSubmitError.swift
- **IMPLEMENT**: Map `APIError` to `SubmitFailure`: `.conflict(code: "booking_conflict", _)` -> `.conflict` with the fixed PRD string "This spot is already booked for that time. Please choose a different window." (client-owned copy, not the server message); `.validation(_, fields)` with `start_time`/`end_time` -> `.invalidWindow(message)`; `.forbidden`/`.profileIncomplete` -> `.notAllowed` ("Your account can't request bookings yet." / route to profile completion via existing plan 01 handling); `.notFound` -> `.listingUnavailable` ("This spot is no longer available."); `.rateLimited` -> "Too many requests. Please try again in a moment."; `.offline` -> `.offline` ("You're offline. Booking requests need an internet connection. Try again when you're back online."); `.server`/`.unknown`/`.decoding` -> `.generic` (retryable); `URLError.timedOut` (a request that may have reached the server) -> `.uncertain` ("We couldn't confirm your request. Check My Bookings before trying again.", with a "View My Bookings" action and **no automatic retry**); `.unauthorized` -> none (session handling).
- **VALIDATE**: covered by `ConfirmationSummaryViewModelTests`.

### CREATE Features/RequestBooking/ConfirmationSummaryViewModel.swift, ConfirmationSummaryView.swift
- **IMPLEMENT**: `@Observable @MainActor final class ConfirmationSummaryViewModel(draft, bookingService, router: ExploreRouter, appRouter: AppRouter, now)`. `state: idle | submitting | failed(SubmitFailure) | submitted(Booking)`. `submit()`: ignore if `.submitting`; re-validate `draft.window.issues(now:)` (start may now be past -> `.failed(.invalidWindow)`); await `createBooking`; success -> `.submitted(booking)` with a success haptic; the pending booking's `totalCents` from the server is displayed (log a `.fault` if it differs from `draft.totalCents`). `goToBookings()`: `appRouter.selectedTab = .bookings` and `pendingDeepLink` for the new booking id (type defined in plan 11; coordinate with plan 06), then `router.popToRoot()`. On `.failed(.conflict)`: set `router.conflictedWindow = draft.window`, primary action "Choose a Different Time" pops one level.
  View: summary card (photo, type, `displayAddress`, date, time range in ET, duration, rate, **total**), `StatusBadge`-style note "Status after submitting: Pending"; payment reminder card with icon: **"You'll pay the host directly in cash, Venmo, or Zelle on arrival."**; disclosure line about sharing the driver's phone (pending product decision, Open Question 3); `PrimaryButton("Send Request")` with loading state; inline `ErrorBanner` per failure with contextual action (Retry for generic, Choose Different Time for conflict, View My Bookings for uncertain). Success state replaces content: checkmark + "Request sent. You'll be notified when the host responds." + `StatusBadge(.pending)` + `PrimaryButton("View My Bookings")` and secondary "Keep Browsing".
- **PATTERN**: `swiftui-development` (loading/disabled states), plan 01 `PrimaryButton` loading.
- **GOTCHA**: Disable Send while submitting and keep the summary visible; back navigation during `.submitting` is blocked (`.navigationBarBackButtonHidden` while submitting). No client timeout below the APIClient 15 s default; the 2 s target is a server/UX metric (show spinner immediately; log elapsed via `OSSignposter` interval `BookingSubmit`). Do not auto-retry on timeouts (could duplicate). VoiceOver: announce "Request sent" via `AccessibilityNotification.Announcement`.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/ConfirmationSummaryViewModelTests`

### UPDATE ExploreRoute, SpotDetailViewModel, Localizable.xcstrings
- **IMPLEMENT**: Add routes and `navigationDestination` cases; plan 04 `requestBooking()` appends `.requestBooking(context)`; `ExploreRouter.conflictedWindow: TimeWindow?` cleared when the selection screen's window changes or a booking succeeds. Add all strings (exact PRD payment reminder and conflict copy, plurals for hours).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE tests, fakes, fixtures
- **IMPLEMENT**: `FakeBookingService` (scripted success/error, suspending variant to test double-tap and cancellation). Reuse `booking-pending.json`, `error-conflict.json`, `error-validation.json` from plan 01; add a validation fixture for `start_time`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`

---

## TESTING STRATEGY

### Unit Tests (Swift Testing, injected `now`)
- `BookingPricingTests`: 500 x 1 h = 500; x 4 h = 2000; x 1.5 h = 750; x 8 h = 4000; 15-minute step exactness; rounding; zero/negative -> nil; DST-elapsed durations.
- `TimeWindowValidationTests`: future-only (start == now invalid); 1 h/8 h boundaries; end <= start; midnight crossing; outside hours; blocked date; disabled weekday.
- `RequestBookingViewModelTests`: defaults; prefilled from When filter; picker changes recompute total; issues surfaced; continue disabled/enabled; conflict banner from `router.conflictedWindow`; re-check of past start at continue.
- `ConfirmationSummaryViewModelTests`: success -> `.submitted`, pending status, server total shown; 409 -> conflict copy and router state; 422 field mapping; offline copy; 403; 404; 429; timeout -> `.uncertain` and no retry; double `submit()` sends one request; start slipped into the past -> not sent; task cancellation does not set failure; tab switch and pop-to-root on success.
- `LiveBookingServiceTests`: body shape (`booking` wrapper, `Z` timestamps, no fractional seconds), auth header, error mapping.
### Edge Cases
Window on DST transition days; device timezone != New York; clock advancing during review; listing deactivated between detail and submit (404); host blocks the date meanwhile (server 422/409, generic handling); two drivers racing (409 for the loser); app backgrounded mid-request (result applied on return); user signs out mid-request (401 handler wins, no crash); airplane mode; Dynamic Type XXL; VoiceOver flow selection -> review -> success; rapid double-tap on Send.
### Manual
Local Rails: create pending booking; second device requests overlapping window -> 409 copy; measure submit latency on LTE < 2 s.

## VALIDATION COMMANDS (from `iOS/`)
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/ConfirmationSummaryViewModelTests -only-testing:SpotiqueTests/BookingPricingTests`
### Level 3: Integration
Full `test` run; stubbed `URLProtocol` service tests; optional run against local Rails when `POST /bookings` exists.
### Level 4: Manual
Map -> pin -> detail -> request -> confirmation -> success -> Bookings tab (plan 06), including conflict and offline paths.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Multi-day / cross-midnight bookings (PRD §8 #3). Assumed single-day: start and end on the same New York date. Overnight parking (e.g. 8 PM - 2 AM) would be rejected. | PRD §8 #3 | Assume single-day |
| 2 | Does the server validate availability schedule and blocked dates on `POST /bookings`? The contract lists only future, 1-8 h, and overlap. Needed as the authority behind the client check. | Contract gap | Pending (API) |
| 3 | Should the review screen disclose that the driver's phone is shared with the host at creation (PRD §7.2)? Recommended yes. | PRD / product | Pending |
| 4 | No idempotency key on `POST /bookings`; propose `Idempotency-Key` header to make retries after timeouts safe. Until then: no auto-retry. | Discovered | Pending (API) |
| 5 | Time slot granularity (assumed 15 min), minimum lead time (assumed start > now only), booking horizon (assumed 30 days) | PRD silent | Assume |
| 6 | Host with no response (PRD §8 #2): pending copy says "You'll be notified"; no auto-decline UI | PRD §8 #2 | Assume none |
| 7 | PRD text says Firestore booking + "date, start time, end time" while Map filter uses duration; REST is used | PRD / README gap 1 | Assume REST |
| 8 | `forbidden` for host-only users on POST; should Explore be hidden for `host` role (plan 03 OQ 4)? | Contract | Pending |
| 9 | Client "cancel request" before host responds (README: no driver cancel) | PRD §8 #5 | Assume none |
| 10 | `docs/api-contract.md` error table still says "Firebase ID token" for 401 (README gap 10) | README | Pending |

## ACCEPTANCE CRITERIA
- [ ] Driver selects date, start, and end time; total (rate x hours, integer cents) updates live
- [ ] Only future slots; duration 1-8 h enforced client-side with clear messages; server 422 mapped
- [ ] Confirmation screen shows summary and exact text: "You'll pay the host directly in cash, Venmo, or Zelle on arrival."
- [ ] 409 `booking_conflict` shows "This spot is already booked for that time. Please choose a different window." and returns to time selection
- [ ] Success creates a `pending` booking, shows a success state, and navigates to the Bookings tab
- [ ] Offline shows a clear error and never queues the request
- [ ] Double-tap and ambiguous timeout do not create duplicate requests
- [ ] Submission latency instrumented; < 2 s on LTE
- [ ] All validation commands pass
- [ ] No regressions; conventions followed; strings localized
- [ ] Privacy model upheld (no address/host phone/payment handle before confirmation)
- [ ] `docs/api-contract.md` updated if availability validation / idempotency key are adopted

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Acceptance criteria met
- [ ] Open questions recorded with decisions

## NOTES
- Selection and confirmation are separate routes so navigation state is value-based (`BookingDraft`) and ViewModels are not recreated on `NavigationStack` re-render.
- The 409 message is client-owned copy so it matches the PRD regardless of server wording; the server `message` is only logged at `.debug` without PII.
- `TimeWindow` type is owned by plan 03; only the validation rules and pricing live here.
- Default MainActor isolation: `BookingPricing`, `TimeWindow+Validation`, and `LiveBookingService` are `nonisolated`.
- Plan 06 must accept `pendingDeepLink`/highlight for a just-created booking and refresh its list on first appear.
