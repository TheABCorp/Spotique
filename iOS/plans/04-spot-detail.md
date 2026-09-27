# Feature: Spot Detail (Gallery, Host Trust, Availability, Redacted Address)

> Validate documentation, codebase patterns, and task sanity before implementing. Depends on plan 03 (`Listing` fetch, `ExploreRouter`, `TimeWindow`, `ListingAvailability`, `ListingPhotoView`, `ListingCache`) and plan 01 (shared types). Reference those by name; do not redefine.

**Source:** `docs/prd-v1.md` §4.4 "P0 — Spot Detail Screen" (+ §6.2 step 2, §7.2, §7.3, §7.4, §8), `docs/api-contract.md` > `GET /listings/:id`, "Bookings" (`POST /bookings` 409), "Error Format", `iOS/plans/README.md`.

## Feature Description

The detail screen for one listing: full-bleed swipeable photo carousel that opens a full-screen gallery, host display name and positive-rating summary, spot type, `display_address` only, hourly rate and the total for the requested window, the host's available hours for a selected day, and a "Request Booking" button that is disabled with an explanation when the requested window cannot be booked. Also owns the reusable `RatingSummaryView` and photo caching for recently viewed spots.

## User Story

As a driver, I want to see a spot's photos, host reputation, price, and hours, so that I can decide whether to request it without seeing the exact address.

## Problem Statement

Drivers need enough information to trust a spot without revealing where exactly it is. The client also has to prevent futile requests (host hours, blocked dates, existing bookings), yet the contract offers no way to see a listing's existing bookings before submitting.

## Solution Statement

`SpotDetailView` renders immediately from the `Listing` passed by the map (via `SpotDetailContext`), then refreshes with `GET /listings/:id` and updates the cache. `SpotDetailViewModel` derives day hours and conflict state from `ListingAvailability` (plan 03) and, once available, server-provided busy intervals. Server `409 booking_conflict` (plan 05) remains the source of truth. Photos load through a disk-backed image cache (actor) with downsampling. `RatingSummaryView` is a small reusable component.

## Requirements & Acceptance Criteria

PRD §4.4 Spot Detail (verbatim):
- Full-screen swipeable photo gallery
- Host display name and positive rating percentage
- Spot type, display address only ("35th Avenue, Jackson Heights" — not the house number)
- Hourly rate and calculated total for the requested duration
- Host's available hours for the selected day
- "Request Booking" button — disabled if a time conflict exists

Acceptance criteria (verbatim):
- Full street address and house number hidden until booking is confirmed
- "Request Booking" disabled with explanation if the time window conflicts with an existing booking

Also §7.3 (VoiceOver, 44pt, contrast, no color-only), §7.4 ("Photos cached locally for recently viewed spots"). Contract `GET /listings/:id`: "Address is redacted to `display_address` unless the caller has a confirmed booking for this listing. Includes `address` only if caller has a confirmed booking." 404 `not_found` if missing.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium
**Platforms**: iOS (Api gap: pre-submit conflict detection, see Open Questions)
**Primary Systems Affected**: `Features/SpotDetail/`, `Services/ListingService.swift` (extend), `Core/Storage/ImageDiskCache.swift`, `ListingPhotoView` (plan 03), `ExploreRoute`
**Dependencies**: ImageIO (downsampling); no new packages

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- Plan 03 outputs: `Features/Map/{ExploreRoute,ListingPhotoView,ListingPreviewCard}.swift`, `Models/{TimeWindow,ListingAvailability,Coordinate}.swift`, `Services/ListingService.swift`, `Core/Storage/ListingCache.swift`, `Core/Extensions/Calendar+Extensions.swift`.
- Plan 01: `Models/Listing.swift` (`address` optional), `Core/DesignSystem/Components/{PrimaryButton,StatusBadge,Card,ErrorBanner,EmptyStateView}.swift`, `Core/Networking/APIError.swift`, `SpotiqueTests/Fakes/`.
- `docs/api-contract.md` lines 251-255, 284-324, 481-502.

### New Files to Create
```
iOS/Spotique/Features/SpotDetail/SpotDetailView.swift
iOS/Spotique/Features/SpotDetail/SpotDetailViewModel.swift
iOS/Spotique/Features/SpotDetail/SpotDetailContext.swift        Hashable route payload (listing, window?)
iOS/Spotique/Features/SpotDetail/PhotoGalleryView.swift         full-screen swipeable viewer
iOS/Spotique/Features/SpotDetail/PhotoCarouselView.swift        hero paging strip
iOS/Spotique/Features/SpotDetail/DayAvailabilityView.swift      day strip + hours
iOS/Spotique/Features/SpotDetail/RatingSummaryView.swift        reusable (plans 12/13)
iOS/Spotique/Features/SpotDetail/RequestButtonState.swift       enum + reason copy
iOS/Spotique/Core/Storage/ImageDiskCache.swift                  actor: disk LRU + downsample
iOS/SpotiqueTests/{SpotDetailViewModelTests,RatingSummaryViewTests,ImageDiskCacheTests}.swift
iOS/SpotiqueTests/Fixtures/{listing-detail.json,listing-detail-confirmed-access.json,availability-busy.json}
```
Updates: `Services/ListingService.swift` (+`busyIntervals`), `SpotiqueTests/Fakes/FakeListingService.swift`, `Features/Map/ListingPhotoView.swift` (use cache), `Features/Map/ExploreRoute.swift` (already routes `.spotDetail`), `Localizable.xcstrings`.

### Documentation — READ BEFORE IMPLEMENTING
- Apple: [Creating a thumbnail with ImageIO](https://developer.apple.com/documentation/imageio/cgimagesource) (`CGImageSourceCreateThumbnailAtIndex`), [TabView page style](https://developer.apple.com/documentation/swiftui/tabviewstyle), [`fullScreenCover`](https://developer.apple.com/documentation/swiftui/view/fullscreencover(ispresented:ondismiss:content:)), [AttributedString/String Catalog plurals](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog).
- `docs/api-contract.md` § Listings, § Bookings.

### Skills to Apply
`swiftui-development` (composition, accessibility, previews), `mvvm-architecture`, `spotique-brand-ui`, `liquid-glass-design` (bottom action bar, close button on gallery), `ios-performance` (downsample, decode off main), `swift-actor-persistence` (`ImageDiskCache`), `ios-security-review`, `ios-api-client`.

### Patterns to Follow
Plan 03 `MapViewModel` state style; plan 01 components. Hero uses `TabView { … }.tabViewStyle(.page)` sized by `containerRelativeFrame`; full-screen viewer via `.fullScreenCover(item:)`. Dates formatted with `Date.FormatStyle` in `TimeZone.spotique`.

---

## PRIVACY & SECURITY

- **Shown:** `displayAddress` only, spot type, rate, host `hostDisplayName` ("Jane D"), rating summary, photos, description, host hours. **Never rendered here even if present:** `Listing.address` (returned when the caller already has a confirmed booking) — the reveal belongs to plan 06's confirmed booking detail. Copy under the address: "Exact address is shared after the host confirms." Host phone is never in listing payloads.
- Detail does not show `paymentMethodText` (may contain a Venmo handle; PRD §4.5 reveals it post-confirmation). Flag to API as in plan 03.
- Cache: `CachedListing` drops `address` (plan 03). The image cache stores photo bytes only, keyed by SHA-256 of the URL (no URL/PII in filenames), stored in `Caches/` (excluded from backup, purgeable), cleared on sign-out.
- No mini-map on this screen: even fuzzed coordinates should not be presented as a precise pin until the API fuzzing decision (plan 03 Open Question 1) is made.
- Own listing: if `listing.hostId == currentUser.id`, show "This is your listing" instead of the request button.
- Photo URLs: verify they are not signed URLs that expire (cache validity); use HTTPS only.

## IMPLEMENTATION PLAN

### Phase 1: Foundation
`SpotDetailContext`, `RatingSummaryView`, `ImageDiskCache`, `ListingServicing.busyIntervals` (protocol + fake), fixtures.
### Phase 2: Core Implementation
`SpotDetailViewModel` (state, day selection, conflict/CTA state), views (carousel, gallery, availability, summary).
### Phase 3: Integration
Wire `.spotDetail` route; `ListingPhotoView` -> `ImageDiskCache`; hand off to plan 05 via `ExploreRoute.requestBooking` (added in plan 05); cache refresh and sign-out purge.
### Phase 4: Testing & Validation

---

## STEP-BY-STEP TASKS

### CREATE Features/SpotDetail/RatingSummaryView.swift
- **IMPLEMENT**: `RatingSummaryView(positivePct: Int?, count: Int, style: .compact/.regular)`. Copy: "94% positive · 17 bookings"; `count == 0` -> "New host" with no percentage (never "0%"); localized plurals ("1 booking"); icon `hand.thumbsup.fill` plus text; `accessibilityLabel` "94 percent positive, 17 bookings". Input mirrors `Listing.hostRatingPositivePct/hostRatingCount` and `User.ratingPositivePct/ratingCount` so plans 12/13 reuse it.
- **PATTERN**: plan 01 components; String Catalog plural variations.
- **GOTCHA**: The contract's `host_rating_count` is a rating count, not necessarily bookings; word as "ratings" if product agrees (Open Question). Do not use color alone for good/bad.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/RatingSummaryViewTests`

### CREATE Core/Storage/ImageDiskCache.swift; UPDATE Features/Map/ListingPhotoView.swift
- **IMPLEMENT**: `actor ImageDiskCache` — `image(for: URL, maxPixelSize: CGFloat) async -> UIImage?`: check memory `NSCache`, then disk file (`Caches/ListingPhotos/<sha256>.jpg`), else download with a dedicated `URLSession`, write data, downsample with ImageIO to `maxPixelSize` (display size x scale) off the main actor. LRU cap 100 MB / 150 files, evict by last access; `purge()` on sign-out. `ListingPhotoView(url:, targetSize:)` calls it with a placeholder and a shimmer-free skeleton; failure shows a neutral icon placeholder (no broken image); has `prefetch(urls:)` used when the detail opens.
- **PATTERN**: `swift-actor-persistence` (in-memory cache + file-backed store behind an actor).
- **GOTCHA**: Cancel loads when the view disappears (`.task(id: url)`). Offline: serve disk hits even if stale (PRD §7.4). Cache original bytes (not the downsampled image) so full-screen gallery gets a larger decode. Do not use `AsyncImage` for detail/gallery (no disk persistence guarantees).
- **VALIDATE**: `... test -only-testing:SpotiqueTests/ImageDiskCacheTests` (URLProtocol stub, LRU eviction, purge, hit without network)

### UPDATE Services/ListingService.swift (+ FakeListingService)
- **IMPLEMENT**: Add `func busyIntervals(listingID: String, in window: DateInterval) async throws -> [DateInterval]`. Live implementation calls the proposed endpoint (Open Question 1) `GET /listings/:id/availability?from=&to=` returning `{"data":{"busy":[{"start_time":"…Z","end_time":"…Z"}]}}` (pending + confirmed merged, no booking ids, status, or driver data). Until the API ships, `LiveListingService` throws `APIError.notFound`-mapped `unsupported` handled by the VM as "unknown" (button stays enabled; server 409 decides).
- **PATTERN**: plan 03 `LiveListingService`; `ios-api-client`.
- **GOTCHA**: Adding a protocol requirement breaks existing conformers: update `FakeListingService` in the same commit.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE Features/SpotDetail/SpotDetailContext.swift, RequestButtonState.swift, SpotDetailViewModel.swift
- **IMPLEMENT**: `SpotDetailContext: Hashable {listing: Listing, window: TimeWindow?}`. `@Observable @MainActor final class SpotDetailViewModel(context, listingService, cache, currentUserID, now, clock)`. State: `listing`, `loadState` (`.showing` (prefetched) / `.refreshing` / `.refreshFailed(APIError)` / `.unavailable` (404 or `active == false`)), `window: TimeWindow?`, `selectedDay: Date` (default window's day else today, NY), `busy: [DateInterval]?` (nil = unknown). Derived: `dayHours: DayHours` (from `ListingAvailability.hours(on:)`), `totalCents: Int?` (rate x window hours, computed with plan 05's `BookingPricing` once available; before that the same formula, integer cents), `requestState: RequestButtonState` = `.enabled`, `.disabled(reason)` where reason is one of: `dayClosed`, `blockedDate`, `outsideHours(hours)`, `busy`, `pastWindow`, `ownListing`, `listingUnavailable`; `.needsTime` when no window (button enabled, leads to plan 05 time picker). Actions: `load()` (refresh + `cache.markViewed`, `prefetch` photos, fetch `busyIntervals` for the selected day), `selectDay(_:)`, `setWindow(_:)`, `requestBooking()` -> `router.path.append(.requestBooking(...))` (route added in plan 05), `retry()`. Precedence for the disabled reason: unavailable > own listing > blocked date > closed day > outside hours > busy.
- **PATTERN**: plan 03 `MapViewModel`; `mvvm-architecture`.
- **GOTCHA**: Client check is advisory; never present "Available" as a guarantee ("Host hours: 8:00 AM - 6:00 PM"). Refresh must not blank the screen; keep the prefetched listing while refreshing. If refresh returns `address` (confirmed-booking caller), ignore it. Cancel refresh on disappear.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/SpotDetailViewModelTests`

### CREATE Features/SpotDetail/PhotoCarouselView.swift, PhotoGalleryView.swift
- **IMPLEMENT**: Hero `TabView(.page)` (1-4 photos), full width, ~4:3, counter pill "2 / 4" (text, not dots alone). Tap -> `PhotoGalleryView` in `fullScreenCover`: black background, paging swipe, pinch/double-tap zoom, close button (glass, 44 pt, top leading), swipe-down to dismiss, starts at tapped index. Zero photos (defensive): neutral placeholder with type icon.
- **GOTCHA**: Gallery decodes at up to screen pixel size only. VoiceOver: each page "Photo 2 of 4", adjustable via swipe up/down; close has label "Close photos". Respect Reduce Motion.
- **VALIDATE**: build; previews (1, 4 photos, loading, failed).

### CREATE Features/SpotDetail/DayAvailabilityView.swift
- **IMPLEMENT**: Horizontal 14-day strip (weekday + date, NY calendar, 44 pt cells) bound to `selectedDay`; below it "Host hours: 8:00 AM - 6:00 PM" or "Not available on this day" or "Host blocked this date"; busy blocks (when known) listed as "Already booked 1:00 PM - 3:00 PM" (time only, no person). If the requested window is set, state whether it is inside the hours with icon + text. Overnight schedules render "10:00 PM - 2:00 AM (next day)". Format with the device locale in `TimeZone.spotique`; when device zone differs show "Times are in New York (ET)".
- **GOTCHA**: Selected/disabled day states use icon/label plus color (strikethrough or "Closed" text), not color alone. The strip must be accessible as a list with labels like "Saturday June 1, closed".
- **VALIDATE**: build; preview at XXL Dynamic Type.

### CREATE Features/SpotDetail/SpotDetailView.swift
- **IMPLEMENT**: `ScrollView`: carousel; title row (spot type icon + "Driveway" + `StatusBadge`-free), `displayAddress`, disclosure line about address; host row (`hostDisplayName` + `RatingSummaryView`); rate "$5/hr" and, if window set, "Total $20.00 for 4 hours (Sat 10:00 AM - 2:00 PM)"; otherwise "Choose a time to see your total"; description; `DayAvailabilityView`. Bottom safe-area glass action bar: `PrimaryButton("Request Booking")` (disabled state shows reason text directly above in body-size text with an info icon: e.g. "The host isn't available at that time. Hours: 8:00 AM - 6:00 PM." / "This spot is already booked for that time. Please choose a different window."). States: skeleton while first load without prefetch; `.unavailable` -> `EmptyStateView` ("This spot is no longer available", back action); `.refreshFailed` -> non-blocking `ErrorBanner(retry:)`; offline -> "You're offline. Showing saved details." banner.
- **PATTERN**: `swiftui-development`, `liquid-glass-design`.
- **GOTCHA**: Disabled buttons must still expose the reason to VoiceOver (`accessibilityHint` + visible text, not a tooltip). Money via `FormatStyle.Currency` from cents. Never interpolate `address`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; previews for each `requestState`.

### UPDATE Features/Map/ExploreRoute.swift wiring, Localizable.xcstrings
- **IMPLEMENT**: `navigationDestination(for: ExploreRoute.self)` builds `SpotDetailView(viewModel:)` from `AppEnvironment` (`listingService`, `listingCache`, `sessionStore.currentUser?.id`). Add all new strings including plural forms.
- **VALIDATE**: build; grep String Catalog for the new keys: `grep -c "Request Booking" Spotique/Localizable.xcstrings`.

### CREATE tests and fixtures
- **IMPLEMENT**: See Testing Strategy. Fixtures copied from the contract plus a confirmed-access variant containing `address`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`

---

## TESTING STRATEGY

### Unit Tests
- `SpotDetailViewModelTests`: renders prefetched listing without a network call, then refreshes; refresh failure keeps content and sets `.refreshFailed`; 404 and `active == false` -> `.unavailable`; window inside hours -> enabled; outside hours / disabled weekday / blocked date / busy interval overlap -> disabled with the right reason and precedence; unknown busy (endpoint missing) -> enabled; own listing -> `ownListing`; total = rate x hours in cents (500 x 4h = 2000; 1.5 h = 750; 8 h max); day change recomputes hours; `address` from a confirmed-access payload is never exposed by the VM's display properties; cancellation on disappear.
- `RatingSummaryViewTests`: formatting for (94, 17), (100, 1) -> "1 booking", (nil, 0) -> "New host", accessibility label.
- `ImageDiskCacheTests`: hit/miss, downsample size, LRU eviction, purge, offline serve.
### Edge Cases
Photos 1 vs 4; broken photo URL; listing deactivated between map and detail; availability with `enabled: true` but missing start/end (treat closed, log); DST days (2026-03-08, 2026-11-01) for hours and totals; window spanning midnight (client shows "outside hours" unless overnight schedule covers it); blocked date on the second day; host hours end exactly at window end (allowed); device timezone not NY; offline with cached listing and cached photos; Dynamic Type XXL; VoiceOver over gallery; rapid back/forward navigation.

## VALIDATION COMMANDS (from `iOS/`)
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/SpotDetailViewModelTests`
### Level 3: Integration
Full `test` run; stubbed service decoding of `listing-detail-confirmed-access.json`.
### Level 4: Manual
Simulator: map -> pin -> card -> detail -> swipe photos -> full-screen; airplane mode after viewing (photos and text still render); VoiceOver through the screen; Instruments Allocations while paging photos (no growth).

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | **Contract gap:** no endpoint exposes a listing's existing bookings, so a pre-submit conflict check is impossible client-side. Propose `GET /listings/:id/availability?from&to` returning merged busy intervals (pending + confirmed; no identities), or a `busy_intervals` field on `GET /listings/:id`. | Contract vs PRD §4.4 AC | Pending (API) |
| 2 | Is `host_rating_count` a count of ratings or bookings ("17 bookings")? | Contract | Assume ratings; copy "ratings" if confirmed |
| 3 | Should `GET /listings/:id` for a confirmed driver still return `address`? Detail ignores it either way. | Contract | Assume yes; ignored here |
| 4 | Overnight availability (`end` earlier than `start`) semantics and whether bookings may cross midnight | Contract / PRD §8 #3 | Assume end<start = overnight; single-day bookings |
| 5 | Mini-map on detail: only if coordinates are fuzzed by the API | Privacy | Pending (plan 03 OQ 1) |
| 6 | Host profile photo (PRD §8 #1) | PRD §8 | Assume none |
| 7 | Are photo URLs long-lived (cacheable) or signed/expiring? | Discovered | Pending |
| 8 | Show host distance/"about" location text beyond `display_address`? | Discovered | Assume no |
| 9 | Firebase vs REST | README gap 1 | Assume REST |

## ACCEPTANCE CRITERIA
- [ ] Swipeable hero carousel and full-screen gallery work with 1-4 photos and VoiceOver
- [ ] Host display name and positive-rating summary shown via reusable `RatingSummaryView`
- [ ] Only `display_address` rendered; house number/`address` never shown or cached
- [ ] Hourly rate and total for the requested duration (integer cents) shown
- [ ] Host hours for the selected day shown in New York time, including blocked/closed days
- [ ] "Request Booking" disabled with a visible explanation on conflict (client-known reasons; server 409 handled in plan 05)
- [ ] Recently viewed photos load offline from disk cache; cache purged on sign-out
- [ ] All validation commands pass
- [ ] No regressions; conventions followed; strings localized
- [ ] Privacy model upheld
- [ ] `docs/api-contract.md` updated if the availability endpoint is adopted

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Acceptance criteria met
- [ ] Open questions recorded with decisions

## NOTES
- Conflict detection is layered: (1) client rules from schedule/blocked dates, (2) busy intervals once the API exists, (3) server 409 as truth. The button is only *disabled* for (1)/(2); (3) is shown after submit.
- `RatingSummaryView` lives here but sits in `Features/SpotDetail/` only for ownership; move to `Core/DesignSystem/Components/` if a third feature imports it.
- `ImageDiskCache` should also serve plan 03's preview thumbnails; do not create a second cache.
- Default MainActor isolation: `ImageDiskCache` is an `actor` (nonisolated); decoding helpers are `nonisolated`.
