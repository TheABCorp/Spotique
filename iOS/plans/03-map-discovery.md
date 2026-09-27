# Feature: Map & Discovery (Google Maps, Pins, "When" and Type Filters, Preview Card)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities, and import from the right files. Shared types (`APIClient`, `Endpoint`, `PagedResponse`, `APIError`, `SessionStore`, `AppRouter`, `AppEnvironment`, design-system components, `Listing`/`SpotType`/`DaySchedule`, `StubURLProtocol`, fixtures) are defined in [01-foundation](01-foundation.md); reference, do not redefine.

**Source:** `docs/prd-v1.md` §4.4 "P0 — Map View" (+ §6.2 steps 1-2, §7.1, §7.3, §7.4, §8), `docs/api-contract.md` "Listings" > `GET /listings`, "Enums", "Error Format", `iOS/plans/README.md`.

## Feature Description

The Explore tab: a Google Map centered on 37th Ave / 74th St, Jackson Heights (~40.7488, -73.8913, zoom 15) showing active listings as custom pins (spot-type icon + hourly rate). Drivers filter by a "When" window (date + start + duration) and by spot type (Both / Driveway / Garage), tap a pin for a preview card (photo, type, rate, distance from the driver), and continue to Spot Detail (plan 04). Previously loaded listings are cached in SwiftData for offline display.

## User Story

As a driver, I want to see available private spots on a map for the time I need, so that I can quickly find one close to my destination.

## Problem Statement

Drivers have no way to discover spots. The map must load fast (< 3 s on LTE), stay smooth with many pins, respect the privacy model (no house-level location), work without location permission, and degrade gracefully offline.

## Solution Statement

`ExploreRootView` hosts a `NavigationStack` (typed `ExploreRoute` path owned by `ExploreRouter`) whose root is `MapView`. `MapViewModel` owns filter state, camera region, and a load state machine; it calls `ListingServicing.listings(query:)` (debounced, cancel-in-flight, stale-while-revalidate against `ListingCache`). Rendering goes through `GoogleMapView: UIViewRepresentable` (Google Maps SDK for iOS via SPM) with diffed markers keyed by listing id, pre-rendered pin images, and simple screen-grid clustering at low zoom. Distance uses optional CoreLocation "when in use"; denial never blocks the map. A "List" toggle provides a VoiceOver-friendly alternative to the map.

## Requirements & Acceptance Criteria

PRD §4.4 Map View (verbatim):
- Google Maps centered on Jackson Heights (37th Ave / 74th St, zoom 15)
- Available spots shown as custom pin markers with spot type icon and hourly rate
- Driver can set a "When" filter: date + start time + duration — map updates to show only available spots for that window
- Tap a pin to open a spot preview card (photo, type, rate, distance from current location)
- Filter by spot type: Driveway / Garage / Both (default: Both)

Acceptance criteria (verbatim):
- Map loads within 3 seconds on LTE connection
- Only active listings with availability covering the selected time window are shown
- When no "When" filter is set, all active listings are shown
- Minimum 44pt touch target on all pins and interactive elements

Also: §7.3 (VoiceOver, 44pt, contrast, no color-only state), §7.4 ("Previously loaded map data ... shown from cache when offline"), §7.2 (Maps key restricted to bundle ID; address hidden in map view). Contract: `GET /listings` params `lat, lng, radius_mi (default 0.5), available_from, available_to (ISO 8601), spot_type, page, per_page (max 50)`; response `{data:[Listing], meta.pagination{page,per_page,total}}`.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: High (third-party SDK, map rendering perf, offline cache, location)
**Platforms**: iOS (Api: `GET /listings` must exist first; build against fakes/fixtures until it lands)
**Primary Systems Affected**: `Features/Map/`, `Services/ListingService.swift`, `Core/Storage/`, `Core/Location/`, `App/AppEnvironment.swift`, `MainTabView`, pbxproj (SPM), Info.plist
**Dependencies**: Google Maps SDK for iOS (`https://github.com/googlemaps/ios-maps-sdk`, product `GoogleMaps`; use the latest stable tag at implementation time, verify iOS 26 support in release notes), CoreLocation, SwiftData

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- Plan 01 outputs: `App/AppEnvironment.swift`, `App/AppRouter.swift` (`selectedTab`), `Core/Networking/{APIClient,Endpoint,APIError,JSONCoding}.swift`, `Models/{Listing,Enums}.swift`, `Core/Storage/ModelContainerFactory.swift`, `Core/DesignSystem/Components/{Card,ErrorBanner,EmptyStateView,LoadingOverlay}.swift`, `Core/Logging/Log.swift`, `SpotiqueTests/Fakes/StubURLProtocol.swift`, `Fixtures/listing.json`.
- `iOS/Spotique.xcodeproj/project.pbxproj` — `INFOPLIST_KEY_*` settings, `GENERATE_INFOPLIST_FILE`, bundle ID `com.actionman.Spotique`; SPM package reference will be added here.
- `docs/api-contract.md` lines 163-215 (`GET /listings`), 468-479 (enums).

### New Files to Create
```
iOS/Spotique/Features/Map/ExploreRootView.swift        NavigationStack host + tab root
iOS/Spotique/Features/Map/ExploreRoute.swift           enum ExploreRoute + @Observable ExploreRouter (path)
iOS/Spotique/Features/Map/MapView.swift                SwiftUI screen: map, filter bar, card, list toggle
iOS/Spotique/Features/Map/MapViewModel.swift
iOS/Spotique/Features/Map/GoogleMapView.swift          UIViewRepresentable + Coordinator (GMSMapViewDelegate)
iOS/Spotique/Features/Map/ListingPin.swift             value type (id, coordinate, spotType, rateText, a11yLabel)
iOS/Spotique/Features/Map/PinImageRenderer.swift       SwiftUI -> UIImage, cached by style
iOS/Spotique/Features/Map/PinClusterer.swift           pure grid clustering (@concurrent)
iOS/Spotique/Features/Map/ListingPreviewCard.swift
iOS/Spotique/Features/Map/ListingResultsListView.swift accessible list alternative (uses ListingSummaryRow)
iOS/Spotique/Features/Map/WhenFilterSheet.swift, WhenFilterViewModel.swift
iOS/Spotique/Features/Map/SpotTypeFilter.swift, MapFilterBar.swift
iOS/Spotique/Features/Map/ListingPhotoView.swift       thin wrapper over AsyncImage (plan 04 swaps in cached loader)
iOS/Spotique/Core/Maps/MapSDK.swift                    idempotent GMSServices key setup
iOS/Spotique/Core/Location/{LocationProviding,LiveLocationProvider,DistanceFormatter}.swift
iOS/Spotique/Models/{Coordinate,TimeWindow,ListingQuery,ListingAvailability}.swift
iOS/Spotique/Services/ListingService.swift             ListingServicing + LiveListingService
iOS/Spotique/Core/Storage/{CachedListing,ListingCache}.swift
iOS/Spotique/Core/Extensions/Calendar+Extensions.swift Calendar.spotique / TimeZone.spotique (America/New_York)
iOS/Config/Secrets.example.xcconfig (+ gitignored Secrets.xcconfig), iOS/Spotique/Info.plist (GMSApiKey only)
iOS/SpotiqueTests/{MapViewModelTests,ListingQueryTests,TimeWindowTests,ListingAvailabilityTests,PinClustererTests,ListingCacheTests,LiveListingServiceTests,WhenFilterViewModelTests}.swift
iOS/SpotiqueTests/Fakes/{FakeListingService,FakeListingCache,FakeLocationProvider,ImmediateClock}.swift
iOS/SpotiqueTests/Fixtures/{listings-page.json,listings-empty.json}
```

### Documentation — READ BEFORE IMPLEMENTING
- [Google Maps SDK for iOS: Get started / SPM](https://developers.google.com/maps/documentation/ios-sdk/config) — Why: package URL, `GMSServices.provideAPIKey`, must-enable "Maps SDK for iOS" on the key.
- [Markers / custom marker images](https://developers.google.com/maps/documentation/ios-sdk/marker) — Why: `GMSMarker.icon` vs `iconView` (`tracksViewChanges` cost), `groundAnchor`, `accessibilityLabel`.
- [Restrict API keys](https://developers.google.com/maps/api-security-best-practices) — Why: iOS-app restriction by bundle ID `com.actionman.Spotique`; restrict to Maps SDK for iOS API only.
- Apple: [CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager), [ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer), [SwiftData @ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor).

### Skills to Apply
`mvvm-architecture` (VM/service/router), `swiftui-development`, `liquid-glass-design` (floating filter bar, card, locate button via `glassEffect`/`GlassEffectContainer`), `spotique-brand-ui` (pin colors: navy fill, ivory text, gold accent), `ios-performance` (marker diffing, clustering, debounce, cancel), `ios-api-client`, `swift-actor-persistence` + SwiftData (cache), `ios-security-review` (location purpose string, no exact coordinates, no address), `swift-concurrency-6-2` (`@concurrent` clustering; default MainActor).

### Patterns to Follow
Per plan 01: `@Observable @MainActor final class MapViewModel`, single `LoadState` enum, services as `Sendable` protocols with `Live*` structs taking `APIClient`, models `nonisolated`. `@ModelActor` types are nonisolated actors: keep SwiftData access in `SwiftDataListingCache` only. Log with `Log.ui`/`Log.network`; never log coordinates of the user or listings above `.private`.

---

## PRIVACY & SECURITY

- **Visible at this stage:** `display_address` (street only), spot type, rate, host first name + last initial, rating, photos, approximate location. **Never** held/cached/rendered: `address`, host phone, driver phone. `payment_method_text` (contract example: "Cash or Venmo @janed") is a Venmo handle that identifies the host; PRD §4.5 reveals payment method only after confirmation. **Flag to API:** omit `payment_method_text` from non-confirmed responses. Client defensively ignores it: not shown, not in `CachedListing`.
- **Coordinates flag (important):** the contract's `latitude/longitude` are the listing's geocoded coordinates (the same values sent in `POST /listings`). Precise coordinates plus reverse geocoding reveal the house number, defeating PRD §7.2. **Recommend the API return deterministic, per-listing fuzzed coordinates** (e.g. snapped to the block centerline plus a stable 50-100 m offset, not re-randomized per request so it cannot be averaged out) to anyone without a confirmed booking, and exact only inside the confirmed booking payload. The client renders exactly what the API returns, never reverse-geocodes, never derives an address, and labels distance as approximate ("about 0.3 mi").
- Listing photos and `description` are host-authored and may show house numbers or plates; API/moderation concern, noted in Open Questions.
- **Google Maps key:** build setting `GOOGLE_MAPS_API_KEY` from gitignored `Secrets.xcconfig` (CI: Xcode Cloud secret env var written by a `ci_scripts` step, see `xcode-cloud`), surfaced via `Info.plist` key `GMSApiKey`. Restrict in Cloud Console to iOS bundle ID `com.actionman.Spotique` and the Maps SDK for iOS API; the key remains extractable from the binary, so restriction plus quota alerts are the mitigation. Use a separate key for Debug if the team wants simulator/bundle-ID isolation.
- **Location:** "When in use" only, `NSLocationWhenInUseUsageDescription` ("Spotique uses your location to show how far each spot is from you."), reduced accuracy is acceptable, coarse `kCLLocationAccuracyHundredMeters`, no background updates, user location never sent to the API (the query center is the map center, not the user) and never persisted.
- **Cache:** `CachedListing` stores only fields above; cleared on sign-out (hooked into `SessionStore.signOut()` via the cache in `AppEnvironment`). Store uses default file protection (`completeUntilFirstUserAuthentication`).
- Auth required: `GET /listings` is called with the bearer token; a 401 goes through plan 01 handling.

## IMPLEMENTATION PLAN

### Phase 1: Foundation
SPM + key config + Info.plist; `Coordinate`, `TimeWindow`, `ListingQuery`, `ListingAvailability`, `Calendar.spotique`; `ListingServicing`; `CachedListing` + `ListingCache`; location provider.

### Phase 2: Core Implementation
`MapViewModel` state machine; `GoogleMapView` + coordinator, pin rendering, clustering; filter bar, When sheet, preview card, list alternative.

### Phase 3: Integration
`ExploreRouter`/`ExploreRoute` (`.spotDetail(SpotDetailContext)`; plans 04/05 add cases), replace Explore tab placeholder, register services in `AppEnvironment`, sign-out cache purge, strings.

### Phase 4: Testing & Validation
ViewModel, query mapping, TimeWindow/availability (DST), clustering, cache, service decode tests; on-device perf check.

---

## STEP-BY-STEP TASKS

### UPDATE Spotique.xcodeproj (add Google Maps SPM package) — manual Xcode step
- **IMPLEMENT**: Xcode > File > Add Package Dependencies > `https://github.com/googlemaps/ios-maps-sdk`, "Up to Next Major", link product `GoogleMaps` to the `Spotique` app target only (not test targets). Commit `Spotique.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- **GOTCHA**: The project uses file-system-synchronized groups for sources, but package references live in `project.pbxproj` and cannot be auto-picked-up; do not hand-edit pbxproj, use Xcode. CI (Xcode Cloud) needs the committed `Package.resolved`. The first resolve is slow (large binary xcframework); do not put it in a timed validation.
- **VALIDATE**: `xcodebuild -resolvePackageDependencies -project Spotique.xcodeproj -scheme Spotique && xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE Config/Secrets.example.xcconfig, Spotique/Info.plist; UPDATE build settings and .gitignore
- **IMPLEMENT**: `Secrets.example.xcconfig` with `GOOGLE_MAPS_API_KEY = REPLACE_ME`; add `Config/Secrets.xcconfig` to `.gitignore`; attach the xcconfig to Debug/Release base configuration. `Info.plist` contains only `GMSApiKey = $(GOOGLE_MAPS_API_KEY)`; keep `GENERATE_INFOPLIST_FILE = YES` and set `INFOPLIST_FILE = Spotique/Info.plist` (Xcode merges both). Add `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`.
- **GOTCHA**: Custom keys cannot be injected via `INFOPLIST_KEY_*` (only Apple-known keys), hence the partial plist. Missing xcconfig must not break the build; the app shows a "Map unavailable" state instead of crashing.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build` then `plutil -extract GMSApiKey raw <built Info.plist>`.

### CREATE Core/Extensions/Calendar+Extensions.swift
- **IMPLEMENT**: `TimeZone.spotique = America/New_York`; `Calendar.spotique` (gregorian, that zone, `en_US_POSIX`-independent locale-neutral).
- **PATTERN**: plan 01 `Date+Extensions.swift`.
- **VALIDATE**: covered by `TimeWindowTests`.

### CREATE Models/Coordinate.swift, TimeWindow.swift, ListingQuery.swift
- **IMPLEMENT**: `Coordinate: Hashable, Sendable {latitude, longitude}` (+ `MapRegion {center, radiusMi}`); `TimeWindow: Hashable, Sendable {start: Date, end: Date}` with `init(day:startMinutes:duration:calendar:)` (uses `Calendar.spotique` `date(bySettingHour:minute:second:of:)`, never adds 86400 s across days), `duration`, `durationHours: Double`, `crossesLocalMidnight`, `isFuture(now:)`. No validation rules here (min 1 h / max 8 h / future live in plan 05 as `TimeWindow+Validation.swift`). `ListingQuery {center, radiusMi, window: TimeWindow?, spotType: SpotType?, page, perPage=50}` with `queryItems`: `lat`, `lng` (4 dp), `radius_mi` (2 dp), `spot_type` only when non-nil, `available_from/to` as ISO 8601 UTC `Z`, `page`, `per_page`. `SpotTypeFilter.both.spotType == nil`.
- **GOTCHA**: `CLLocationCoordinate2D` is not Hashable; keep CoreLocation types at the edges only. Both `available_from` and `available_to` are sent together or not at all.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/ListingQueryTests -only-testing:SpotiqueTests/TimeWindowTests`

### CREATE Models/ListingAvailability.swift
- **IMPLEMENT**: Pure, `nonisolated` evaluator over `Listing.availabilitySchedule` + `blockedDates`: `hours(on day: Date) -> DayHours` (`.closed`, `.blocked`, `.open(start: Date, end: Date)`), `evaluate(_ window: TimeWindow) -> AvailabilityResult` (`.covered`, `.outsideHours(DayHours)`, `.blockedDate`, `.dayClosed`). Weekday from `Calendar.spotique`; `"HH:mm"` parsed to minutes in NY; `blocked_dates` `"yyyy-MM-dd"` compared in NY. A window is covered only if fully inside one day's open interval (single-day assumption; end <= start in the schedule is treated as overnight into the next day, flagged in Open Questions). Used here for offline client filtering and by plan 04/05 for display and validation.
- **GOTCHA**: DST (2026-03-08 and 2026-11-01): build day-interval Dates via `Calendar` components, not arithmetic. Disabled days omit `start`/`end` (decoded optional).
- **VALIDATE**: `... test -only-testing:SpotiqueTests/ListingAvailabilityTests`

### CREATE Services/ListingService.swift
- **IMPLEMENT**: `protocol ListingServicing: Sendable { func listings(query: ListingQuery) async throws -> PagedResponse<Listing>; func listing(id: String) async throws -> Listing }` and `struct LiveListingService` over `APIClient` (`GET /listings`, `GET /listings/:id`, `requiresAuth: true`). Extension `listingsAll(query:maxPages:)` fetches sequentially until `meta.pagination.total` is covered or `maxPages` (3 = 150 results); checks `Task.isCancelled` between pages. Plans 04 (busy intervals), 07/08 (create/update/toggle/delete/mine) extend this protocol.
- **PATTERN**: `ios-api-client` skill; plan 01 `LiveAuthService`.
- **GOTCHA**: `per_page` max 50. Mark service `nonisolated`/`Sendable` so decoding stays off the main actor.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/LiveListingServiceTests` (StubURLProtocol: query string, page loop, 401, offline).

### CREATE Core/Storage/CachedListing.swift, ListingCache.swift; UPDATE ModelContainerFactory
- **IMPLEMENT**: `@Model final class CachedListing` (id unique, hostDisplayName, hostRatingPositivePct, hostRatingCount, latitude, longitude, displayAddress, spotTypeRaw, hourlyRateCents, descriptionText, photoURLStrings, scheduleJSON `Data`, blockedDates, cachedAt, lastViewedAt). **No** address, phones, payment text, host id. `protocol ListingCaching: Sendable { replace(in: MapRegion, with: [Listing]); listings(in: MapRegion) -> [Listing]; listing(id:) ; markViewed(id:); clear() }`, `@ModelActor actor SwiftDataListingCache`. Register `CachedListing` in the schema. Policy: upsert by id; on successful online fetch, delete cached rows inside the fetched region that were not returned (deactivated/removed); TTL 7 days; cap 200 rows evicting oldest `lastViewedAt`. `SessionStore.signOut()` calls `clear()`.
- **PATTERN**: `swift-actor-persistence`; `Core/Storage/ModelContainerFactory.swift` in-memory variant for tests.
- **GOTCHA**: The mapper drops `address` even if the API returned it (caller with a confirmed booking). Do not pass `@Model` objects out of the actor; return `Listing` values.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/ListingCacheTests` (upsert, region prune, TTL, cap, no forbidden fields, clear).

### CREATE Core/Location/*
- **IMPLEMENT**: `protocol LocationProviding { var authorization: LocationAuthorization {get}; func requestAuthorization(); func currentLocation() async -> Coordinate? }` (`.notDetermined/.denied/.authorized`), `LiveLocationProvider` wrapping `CLLocationManager` (accuracy 100 m, one-shot `requestLocation`), `DistanceFormatter.text(from:to:)` -> "0.3 mi away" (`Measurement<UnitLength>` in miles, locale-aware, < 0.1 mi -> "Nearby").
- **GOTCHA**: Denied/restricted returns nil; callers omit the distance row; never show an alert loop. Simulator has no location by default.
- **VALIDATE**: build; `FakeLocationProvider` used in VM tests.

### CREATE Core/Maps/MapSDK.swift, Features/Map/GoogleMapView.swift, ListingPin.swift, PinImageRenderer.swift, PinClusterer.swift
- **IMPLEMENT**: `MapSDK.configure()` (main actor, once) reads `GMSApiKey`; empty -> returns `.unavailable`. `GoogleMapView(pins:, selectedID:, cameraCommand:, bottomInset:, onIdle:, onSelect:)`; coordinator keeps `[String: GMSMarker]` and diffs (add/remove/update icon), never `mapView.clear()`. Initial camera lat 40.7488 lng -73.8913 zoom 15; `minZoom 12`, `maxZoom 19`. `onIdle` (delegate `idleAt`) reports `MapRegion` from `projection.visibleRegion()` (center + farthest-corner radius). Markers: `icon` = pre-rendered `UIImage` from `PinImageRenderer` (SwiftUI capsule: SF Symbol `house.fill` for driveway / `door.garage.closed` for garage + "$5/hr", navy fill, ivory text; selected = larger + gold border + heavier weight, not color alone); cache by (spotType, rateText, isSelected, scale, colorScheme). Image padded to min 44x44pt hit area, `groundAnchor` at the bottom-center tip. `marker.accessibilityLabel` = "Driveway, $5 per hour, about 0.3 miles away". `PinClusterer.cluster(pins:, zoom:, projection)` `@concurrent`: grid cells of 64 pt; below zoom 15 or above 60 pins, clusters render as a navy circle with count (tap zooms in one level); at zoom >= 15 individual pins.
- **GOTCHA**: Use `icon`, not `iconView` (avoids `tracksViewChanges` re-rendering cost). Set `mapView.padding.bottom` when the card shows so the Google logo/legal text is never covered (license requirement). Marker icons do not scale with Dynamic Type, so the list alternative is the accessible path. Do not call `GMSServices.provideAPIKey` at app launch (launch budget, plan 01 / `ios-performance`); call it at first `makeUIView`. Coordinator must not retain the ViewModel strongly (use closures).
- **VALIDATE**: `... test -only-testing:SpotiqueTests/PinClustererTests`; build.

### CREATE Features/Map/MapViewModel.swift
- **IMPLEMENT**: `@Observable @MainActor final class MapViewModel`. Init(listingService, cache, location, clock: any Clock<Duration>, now). State: `loadState: LoadState` (`.idle, .loading(previous: [Listing]), .loaded, .empty, .offlineCached(cachedAt), .failed(APIError)`), `listings: [Listing]`, `when: TimeWindow?`, `spotFilter: SpotTypeFilter = .both`, `region: MapRegion`, `selectedID: String?`, `userLocation: Coordinate?`, `showsList: Bool`. Derived: `pins: [ListingPin]`, `selectedListing`, `distanceText(for:)`, `emptyStateActions`. Actions: `onAppear()` (show cache instantly, then fetch; request location auth once), `regionDidChange(_:)` (cancels prior task, sleeps 400 ms via injected clock, skips fetch if new visible circle lies inside the last fetched circle with same filters; fetch radius = visible x 1.25, capped 2 mi), `setWhen(_:)`, `clearWhen()`, `setSpotFilter(_:)` (both refetch immediately), `select(_:)`, `deselect()`, `retry()`, `recenterOnUser()`. Stale-response guard via a generation counter plus `Task.isCancelled`; cancelled work never sets `.failed`. On `.offline`: load `cache.listings(in:)`, filter client-side by spot type and by `ListingAvailability` when `when` is set, set `.offlineCached` (banner "Offline. Showing saved spots that may no longer be available."). On success: `cache.replace`. Selected listing that disappears from results is deselected. Only `active` listings are shown (defensive filter).
- **PATTERN**: `mvvm-architecture`; plan 01 `SessionStore` state style.
- **GOTCHA**: Do not fetch on every camera tick, only on `idleAt`. Do not send the user's location. `available_from/to` only when `when != nil`.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/MapViewModelTests`

### CREATE WhenFilterSheet.swift, WhenFilterViewModel.swift, SpotTypeFilter.swift, MapFilterBar.swift
- **IMPLEMENT**: Sheet (`.presentationDetents([.medium])`): date (`DatePicker` `.graphical`/compact, range today...+30 days, `.environment(\.timeZone, .spotique)`), start-time `Picker` over generated 15-minute slots (UIKit-free; SwiftUI `DatePicker` has no minute interval), duration `Picker` 1-8 h in 30-minute steps. Defaults: today, next 15-minute slot after now, 2 h. Buttons: "Apply", "Clear". If device timezone differs from New York, show "Times are in New York (ET)". `WhenFilterViewModel` generates slots (past slots for today excluded), builds `TimeWindow`, exposes `isApplicable`. `MapFilterBar`: glass container with a "When" chip ("Any time" or "Sat 10:00 AM - 2:00 PM", trailing clear button 44 pt) and segmented `Picker` Both / Driveway / Garage (icon + text). Full validation lives in plan 05.
- **GOTCHA**: Filter sheet must not allow start in the past. Chip text uses icon + text, never color only. Localize with `Date.FormatStyle` in NY zone.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/WhenFilterViewModelTests`

### CREATE ListingPreviewCard.swift, ListingResultsListView.swift, ListingPhotoView.swift, MapView.swift
- **IMPLEMENT**: `ListingPreviewCard` bottom overlay (glass, 24 pt radius): `ListingPhotoView` thumbnail, type icon + label, "$5/hr", distance (omitted if unknown), `RatingSummary` line deferred to plan 04's `RatingSummaryView` if available, chevron; whole card is one accessibility element ("Driveway, $5 per hour, about 0.3 miles away. Double tap to view details") with dismiss action. Tap -> `router.path.append(.spotDetail(SpotDetailContext(listing:, when:)))`. `MapView`: map fills the screen, filter bar top, locate-me button + "List" toggle bottom trailing (glass, 44 pt), `LoadingOverlay`-style top progress for `.loading` (map stays interactive), `ErrorBanner(retry:)` for `.failed`, `EmptyStateView` for `.empty` ("No spots match. Try another time or clear filters." + actions "Clear When filter", "Show all types"). `ListingResultsListView` = sorted list (distance when known, else rate) using the same row and route.
- **PATTERN**: `swiftui-development`, `liquid-glass-design` (wrap adjacent glass controls in one `GlassEffectContainer`).
- **GOTCHA**: `ListingPhotoView` is the single swap point for plan 04's disk-cached image loader; here it wraps `AsyncImage` with a placeholder. Keep `body` cheap; the map view must not re-render on each unrelated VM property.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; `#Preview`s (loaded, empty, error, offline, XXL type).

### CREATE ExploreRoute.swift, ExploreRootView.swift; UPDATE MainTabView, AppEnvironment
- **IMPLEMENT**: `enum ExploreRoute: Hashable { case spotDetail(SpotDetailContext) }` (plan 04 defines `SpotDetailContext`; 04/05 add `.requestBooking`, `.bookingConfirmation`), `@Observable @MainActor final class ExploreRouter { var path: [ExploreRoute]; func popToRoot() }`. `ExploreRootView` owns `NavigationStack(path:)` and injects the router. Replace Explore placeholder. Add `listingService`, `listingCache`, `locationProvider` to `AppEnvironment` (live + preview fakes). Add strings to `Localizable.xcstrings`.
- **GOTCHA**: Explore tab visibility for host-only users is a plan 01/README decision (see Open Questions).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE test fakes and fixtures
- **IMPLEMENT**: `FakeListingService` (scripted responses, suspending variant using continuations to test cancellation), `FakeListingCache`, `FakeLocationProvider`, `ImmediateClock`; fixtures copied from the contract example (`listings-page.json` with a disabled day omitting start/end, `listings-empty.json`).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`

---

## TESTING STRATEGY

### Unit Tests (Swift Testing)
- `MapViewModelTests`: initial state and region (40.7488, -73.8913); `.idle -> .loading -> .loaded/.empty/.failed`; cache shown first then replaced; debounce coalesces rapid region changes to one request; superseded/cancelled request never overwrites newer results or sets `.failed`; region-contained change skips fetch; filter changes refetch; `when` maps to `available_from/to`; clearing When restores all listings; offline -> `.offlineCached` with client-side type/availability filtering; selection cleared when listing vanishes; location denied leaves distances nil and map functional; inactive listings never pinned.
- `ListingQueryTests`: `both` omits `spot_type`; rounding; ISO 8601 UTC output (`2026-11-01T14:00:00Z`); pairing of `available_*`.
- `TimeWindowTests` / `ListingAvailabilityTests`: NY timezone from a device in another zone; 2026-03-08 (spring forward) and 2026-11-01 (fall back); window ending exactly at closing time; overnight schedule; blocked date at window end day; disabled day.
- `PinClustererTests`: grouping stable, deterministic, performance guard on 150 pins (`#expect` under a generous bound).
- `ListingCacheTests`, `LiveListingServiceTests` (fixtures, 401 -> `.unauthorized`, pagination loop, cancellation).
### Edge Cases
No listings; all pages > 150 results; location denied/restricted/reduced accuracy; user outside NYC; offline at launch with empty cache (error state with retry); app backgrounded mid-fetch; Dynamic Type XXL on filter bar/card; VoiceOver traversal via list alternative; dark mode map style; two rapid pin taps; listing at same coordinates (cluster/stack) tapped.
### Manual (device, Release)
Time to first pins on LTE (Network Link Conditioner) < 3 s, measured with an `OSSignposter` interval `MapFirstPins`; pan/zoom 60 fps with 150 pins (Instruments: SwiftUI, Time Profiler, Allocations).

## VALIDATION COMMANDS (from `iOS/`)
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`
### Level 3: Integration
`xcodebuild ... test -only-testing:SpotiqueTests/LiveListingServiceTests` (stubbed); optionally run against local Rails once `GET /listings` exists.
### Level 4: Manual
Simulator with a custom location; deny location and confirm the map still works; airplane mode after one load shows cached pins with banner; VoiceOver: list toggle reaches every listing.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Should the API return fuzzed coordinates for non-confirmed callers (recommended) and drop `payment_method_text` pre-confirmation? | Privacy review | Pending (API) |
| 2 | Max `radius_mi` the API accepts, and how availability is evaluated for a window (must be fully inside one day's hours? overnight schedules with end < start?) | Contract gap | Pending |
| 3 | `per_page` cap of 50: acceptable to load up to 3 pages (150), or add a bounding-box query? | Contract | Assume 3 pages |
| 4 | Explore tab for host-only users (role `host`)? `POST /bookings` is driver-only. | README / plan 01 | Assume Explore shown for `driver`/`both` only |
| 5 | Lock the map to Jackson Heights bounds (`cameraTargetBounds`) or allow free pan? | PRD §1 geography | Assume free pan, zoom 12-19 |
| 6 | Contract example listing (40.7496, -73.8783) is ~0.7 mi east of the specified map center; sample data inconsistent with PRD | Contract | Note only |
| 7 | Booking horizon for the When date (assume today +30 days) and 15-minute slot granularity | PRD silent | Assume |
| 8 | PRD says filter = date + start + duration (§4.4) but flow §6.2 says start + end; sheet uses duration, plan 05 uses start/end | PRD | Assume both are valid views of one `TimeWindow` |
| 9 | Location permission timing: on first Explore appear (assumed) or on locate-me tap? | Discovered | Assume first appear |
| 10 | Firebase vs REST (README gap 1); PRD "Firestore" wording is stale | README | Assume REST |
| 11 | Multi-day bookings (PRD §8 #3): When filter is single-day | PRD §8 | Assume single-day |

## ACCEPTANCE CRITERIA
- [ ] Map opens centered 40.7488, -73.8913 at zoom 15 and shows first pins within 3 s on LTE
- [ ] Pins show type icon + hourly rate, >= 44 pt hit area, VoiceOver labels; only active listings shown
- [ ] "When" filter sends `available_from/to`; no filter shows all active listings
- [ ] Both/Driveway/Garage filter (default Both) maps to `spot_type` correctly
- [ ] Preview card shows photo, type, rate, distance (hidden gracefully when location denied)
- [ ] Region changes are debounced and in-flight requests cancelled; no duplicate fetches
- [ ] Offline shows cached listings with a banner; empty/error/loading states present
- [ ] All validation commands pass
- [ ] No regressions; conventions followed; strings localized
- [ ] Privacy model upheld (no address/phone/payment text cached or shown; no reverse geocoding)
- [ ] `docs/api-contract.md` updated if coordinate fuzzing / payment text redaction is adopted

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes; performance measured on device
- [ ] SPM package committed with `Package.resolved`; `Secrets.xcconfig` gitignored
- [ ] Open questions recorded with decisions

## NOTES
- Google Maps chosen per PRD; MapKit would avoid the SDK/key but contradicts the PRD stack. Third-party utils library (`google-maps-ios-utils`) is skipped: custom grid clustering keeps the dependency count at one and gives control of pin visuals.
- Pins are static images for performance; if design later needs animated pins, revisit `iconView` with `tracksViewChanges = false` after first render.
- `TimeWindow`, `ListingAvailability`, `ExploreRouter`, and `ListingPhotoView` are consumed by plans 04 and 05.
- Default MainActor isolation: mark `ListingQuery`, `TimeWindow`, `ListingAvailability`, `PinClusterer`, and the service `nonisolated`.
