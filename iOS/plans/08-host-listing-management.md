# Feature: Host — Manage Listings (Active Toggle, Edit, Blocked Dates, Delete)

> Validate documentation, codebase patterns, and task sanity before implementing. Reuse plan 07's form/step components and validators; reuse plan 01's networking and components. Do not redefine them.

**Source:** `docs/prd-v1.md` §4.2 "P0 — Manage Listing", §7.4 (offline), §8 Q4; `docs/api-contract.md` "Listings → `PATCH /listings/:id`, `PATCH /listings/:id/toggle`, `DELETE /listings/:id`", "Bookings → `GET /bookings`", "Error Format"; `iOS/plans/README.md` gap 4.

## Feature Description

The host's "Listings" tab: a list of the host's own listings (photo, street display, rate, spot type, active switch), a detail/manage screen, an edit form for any field, a blocked-dates calendar editor, and delete with a confirmation dialog. Also exposes a reusable "Active listings" section for plan 13 (Profile).

## User Story

As a host, I want to pause, edit, block dates on, or delete my listings, so that drivers only see spots I can actually offer.

## Problem Statement

Hosts' availability changes (vacations, guests, a sold house). Without management controls, stale listings produce declined requests and no-shows. The API has no "my listings" read endpoint, no bookings count on a listing, and no dedicated blocked-dates endpoint — the client must be designed around those gaps.

## Solution Statement

`MyListingsViewModel` loads via `ListingServicing.myListings()` (endpoint choice isolated in one line), caches non-sensitive fields for offline display, and performs the active toggle optimistically with rollback and per-listing serialization. `ListingEditView` composes plan 07's `ListingFormModel` and step content views as a `Form`, sending a minimal `PATCH` diff. `BlockedDatesEditorView` uses `MultiDatePicker` and saves the full `blocked_dates` array through the same `PATCH`. Deletion asks `ActiveBookingChecking` (built on `GET /bookings?role=host&status=…`) whether pending/confirmed bookings exist and shows the PRD confirmation copy accordingly. After every mutation the client bumps `ListingChangeTracker` (plan 07) so the driver map (plan 03) refetches; the 10-second disappearance is a server/cache guarantee the client cannot enforce.

## Requirements & Acceptance Criteria

**PRD §4.2 Manage Listing (verbatim):**
- Toggle listing active / inactive with a single switch
- Edit any listing field
- Add or remove blocked dates (specific calendar dates when the spot is unavailable)
- Delete listing (requires confirmation dialog)

**Acceptance criteria (verbatim):**
- Inactive listings disappear from the driver map within 10 seconds
- Deletion with active pending/confirmed bookings shows: "Are you sure? Pending bookings will be cancelled."

**Contract:** `PATCH /listings/:id` — host only, any subset of listing fields, 200 returns updated listing. `PATCH /listings/:id/toggle` body `{ "active": false }`, 200 returns listing. `DELETE /listings/:id` — 204; pending/confirmed bookings are cancelled and drivers notified. All edits re-apply `POST` validations (rate 500–5000, ≤ 4 photos ≥ 1, description ≤ 200, ≥ 1 enabled day, address in 11372). Errors: 403 (not owner/host), 404, 422 `details`.

**PRD §7.4:** "user's own listings and bookings are shown from cache when offline."

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium–High
**Platforms**: iOS (needs API additions listed in Open Questions)
**Primary Systems Affected**: `Features/ListingManagement/`, `Services/ListingService*`, `Core/Storage` (own-listing cache), `App/MainTabView` (Listings tab)
**Dependencies**: Plan 07 (`ListingFormModel`, step views, validators, `PhotoUploading`, `ListingChangeTracker`, `create` flow entry), plan 01, plan 02. Plan 03 for map refresh consumption (soft).

**Ordering / ownership of `ListingServicing`:** 03 → 07 → 08. Plan 08 **adds exactly**: `myListings() async throws -> [Listing]`, `update(id: String, patch: ListingPatch) async throws -> Listing`, `toggleActive(id: String, active: Bool) async throws -> Listing`, `delete(id: String) async throws`. Implementations go in `Services/LiveListingService+Manage.swift` under `// MARK: – Plan 08` in the protocol; `FakeListingService` gains matching stubs. Plan 08 may start once plan 07's `ListingFormModel` and step views exist (needed for edit); the list/toggle/delete/blocked-dates portions only need plan 01 and the service file and can start in parallel with 07 if the service file conflict protocol in plan 07 is followed. `AppEnvironment`: adds `activeBookingChecker` only (one line).

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `iOS/plans/07-host-listing-creation.md` — `ListingFormModel`, `ListingValidators`, step views, `PhotoUploading`, `ListingChangeTracker`, service-file conflict protocol.
- `iOS/Spotique/Services/ListingService.swift` (plans 03/07) — protocol shape, `Endpoint` use.
- `iOS/Spotique/Models/Listing.swift` — `active`, `blockedDates: [String]`, `address?`.
- `iOS/Spotique/Core/Networking/{APIClient,Endpoint,APIError}.swift`; `Core/Storage/ModelContainerFactory.swift` (register `CachedOwnListing`).
- `iOS/Spotique/Core/DesignSystem/Components/{Card,StatusBadge,ErrorBanner,EmptyStateView,LoadingOverlay,PrimaryButton}.swift`.
- `iOS/Spotique/App/{RootView,AppRouter,AppEnvironment}.swift` — Listings tab wiring (role gating).
- `iOS/SpotiqueTests/Fakes/FakeListingService.swift`, `Fixtures/listing.json`.

### New Files to Create
```
iOS/Spotique/Features/ListingManagement/MyListingsView.swift
iOS/Spotique/Features/ListingManagement/MyListingsViewModel.swift
iOS/Spotique/Features/ListingManagement/MyListingRow.swift                     photo, street, rate, badge, Toggle
iOS/Spotique/Features/ListingManagement/ListingDetailManageView.swift
iOS/Spotique/Features/ListingManagement/ListingDetailManageViewModel.swift
iOS/Spotique/Features/ListingManagement/ListingEditView.swift
iOS/Spotique/Features/ListingManagement/ListingEditViewModel.swift
iOS/Spotique/Features/ListingManagement/BlockedDatesEditorView.swift
iOS/Spotique/Features/ListingManagement/BlockedDatesViewModel.swift
iOS/Spotique/Features/ListingManagement/ActiveListingsSection.swift            embeddable in plan 13
iOS/Spotique/Features/ListingManagement/DeleteListingConfirmation.swift        copy + presentation model
iOS/Spotique/Services/LiveListingService+Manage.swift
iOS/Spotique/Services/ActiveBookingChecking.swift                              protocol + Live (GET /bookings host)
iOS/Spotique/Services/OwnListingCache.swift                                    protocol + SwiftData impl
iOS/Spotique/Models/{ListingPatch,CachedOwnListing}.swift
iOS/Spotique/Core/Extensions/{DateComponents,Calendar}+Extensions.swift        NY-calendar "yyyy-MM-dd" helpers
iOS/SpotiqueTests/Fakes/{FakeActiveBookingChecker,FakeOwnListingCache}.swift   (+ FakeListingService manage stubs)
iOS/SpotiqueTests/Fixtures/{my-listings.json,listing-inactive.json,bookings-host-pending.json}
iOS/SpotiqueTests/{MyListingsViewModelTests,ListingEditViewModelTests,BlockedDatesViewModelTests,DeleteListingConfirmationTests,ListingPatchEncodingTests,ListingServiceManageTests}.swift
```

### Documentation — READ BEFORE IMPLEMENTING
- [MultiDatePicker](https://developer.apple.com/documentation/swiftui/multidatepicker) — `selection: Binding<Set<DateComponents>>`, `in: PartialRangeFrom<Date>`; components carry the `Calendar`/time zone of the picker's environment.
- [confirmationDialog](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)) / `alert` for destructive confirmation; `Button(role: .destructive)`.
- [SwiftData `@Model`](https://developer.apple.com/documentation/swiftdata) — own-listing cache.
- `docs/api-contract.md` § Listings (PATCH, toggle, DELETE) and § Bookings `GET /bookings`.

### Skills to Apply
`mvvm-architecture`, `swiftui-development` (List swipe actions, accessibility, previews), `spotique-brand-ui`, `liquid-glass-design`, `ios-api-client` (offline/caching, error mapping), `ios-security-review` (cache contents), `swift-actor-persistence`, `swift-concurrency-6-2`.

### Patterns to Follow
- `@Observable @MainActor final class MyListingsViewModel` with `enum LoadState { idle, loading, loaded, empty, failed(APIError) }` plus `staleCache: Bool` banner.
- Optimistic mutation pattern: snapshot old value → mutate local → call service → on failure restore snapshot + surface error; per-id in-flight set prevents overlap.
- Test doubles: `FakeListingService` with scripted results (`Result<Listing, APIError>`) and recorded calls, mirroring plan 01's fakes.

---

## PRIVACY & SECURITY

- Only the owner sees management screens; server enforces host-only/owner-only (403 → localized "You can't change this listing" and refresh). Entry point hidden unless `user.role ∈ {host, both}`.
- The owner's own-listing API response may include `address` (contract only guarantees it for confirmed bookings — Open Question 1). The **cache never stores `address`** (`CachedOwnListing` has no such field); the edit form's address row displays `displayAddress` and asks the host to re-select via `AddressAutocompleteField` only if they want to change it (PATCH sends `address`+`latitude`+`longitude` together or none). If the API returns `address` to the owner, show it only on the host's manage-detail screen ("Your address — only you and confirmed drivers see this"), memory only, never logged, cleared on sign-out.
- Never place full address into driver-facing surfaces; toggling/edit never changes what drivers can see beyond server rules. Delete/update/toggle are authenticated with the JWT via `APIClient`; sign-out clears `CachedOwnListing`.
- Logging: ids only (`privacy: .private` for anything else); never log descriptions, addresses, photo URLs.
- Photo edits reuse plan 07 `ImageProcessing` (EXIF stripped, ≤ 800 KB) and `PhotoUploading`.

## IMPLEMENTATION PLAN

### Phase 1: Foundation — service methods, patch model, cache, date helpers
### Phase 2: Core — list + toggle, detail, blocked dates, edit, delete
### Phase 3: Integration — Listings tab wiring, change tracker, Profile section, offline cache
### Phase 4: Testing & Validation

---

## STEP-BY-STEP TASKS

### ADD ListingServicing.{myListings, update, toggleActive, delete} + LiveListingService+Manage.swift
- **IMPLEMENT**: `myListings()` → `GET /listings?mine=true` (proposed; alternative `GET /users/me/listings`). Keep the choice in one private `static let myListingsEndpoint: Endpoint`; response paged (`PagedResponse<Listing>`) — fetch all pages (host has few listings) with `per_page=50`. `update` → `PATCH /listings/:id` body `{ "listing": ListingPatch }`; `toggleActive` → `PATCH /listings/:id/toggle` body `{ "active": Bool }`; `delete` → `sendEmpty` `DELETE /listings/:id` (204). All `requiresAuth`.
- **PATTERN**: plan 07 `LiveListingService+Create.swift`; plan 01 `APIClient.sendEmpty`.
- **GOTCHA**: Contract has no owner listing endpoint; `GET /listings` requires `lat/lng` and returns other hosts' listings and probably only `active` ones (so inactive listings would be invisible). Any endpoint must return inactive listings of the caller. Until it exists, `FakeListingService` serves fixtures and the app builds against the protocol.
- **VALIDATE**: `cd iOS && xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/ListingServiceManageTests`

### CREATE Models/ListingPatch.swift
- **IMPLEMENT**: `nonisolated struct ListingPatch: Encodable, Sendable` with all-optional fields (`address, latitude, longitude, spotType, hourlyRateCents, description, photos: [String], availabilitySchedule, blockedDates: [String], paymentMethodText`) — synthesized `encodeIfPresent` so absent fields are omitted. `static func diff(from original: Listing, to form: ListingFormModel, photoValues: [String]?) -> ListingPatch` (empty patch → `isEmpty == true`, no request).
- **GOTCHA**: To clear the description send explicit `""` (not nil); model with `enum Field<T> { case unchanged, set(T) }` or a dedicated `clearDescription` flag and test the JSON. `photos` and `blocked_dates` are full-array replacements (contract accepts arrays only) — send the whole final array. `availability_schedule` sent whole (all seven days) when any day changed.
- **VALIDATE**: `… -only-testing:SpotiqueTests/ListingPatchEncodingTests`

### CREATE Services/OwnListingCache.swift + Models/CachedOwnListing.swift
- **IMPLEMENT**: SwiftData `@Model CachedOwnListing` (id, displayAddress, spotTypeRaw, hourlyRateCents, active, primaryPhotoURL, blockedDates, scheduleJSON, updatedAt). No `address`, no host phone. `OwnListingCaching { func load() -> [Listing]; func replaceAll(_:) ; func clear() }`; register schema in `ModelContainerFactory` (plan 01 hook); clear in sign-out path.
- **PATTERN**: `swift-actor-persistence` Spotique Context; plan 06/03 cache models.
- **GOTCHA**: Cache is per signed-in user — clear on sign-out to prevent cross-account leakage.
- **VALIDATE**: build; `MyListingsViewModelTests` with `FakeOwnListingCache`.

### CREATE Features/ListingManagement/MyListingsViewModel.swift
- **IMPLEMENT**: State: `loadState`, `listings: [Listing]`, `isShowingCache`, `inFlightToggles: Set<String>`, `errorBanner: APIError?`, `pendingDeletion: Listing?`. Actions: `load()` (cache first for instant paint, then network; on failure keep cache + banner "Showing saved listings — you're offline" when `.offline`), `refresh()`, `toggle(_ listing:, to active: Bool)`, `requestDelete(_:)`, `confirmDelete()`, `didEdit(_:)`, observe `ListingChangeTracker.revision` and `scenePhase == .active` → silent refetch.
- **Optimistic toggle**: on `toggle`: if id already in-flight, store `desiredActive` and return (latest wins, applied after the in-flight call completes so requests are serialized); else set local `active` immediately, insert id, call `toggleActive`; on success replace with server object (authoritative) and `changeTracker.didChange()`; on failure restore the pre-toggle value, remove id, set `errorBanner`, and post `UIAccessibility` announcement "Couldn't update. Listing is still active." + `.error` haptic. Offline: fail fast without queueing (mutations require a connection; message "You're offline. Connect to change availability.") — Open Question 6.
- **GOTCHA**: The Toggle is bound through `Binding(get:set:)` calling `toggle` (not a raw `$listing.active`) so rollback re-renders the switch. Disable (not hide) the switch while in flight only if the coalescing design is dropped; default keeps it enabled.
- **VALIDATE**: `… -only-testing:SpotiqueTests/MyListingsViewModelTests` (success; failure rollback restores exact prior state; rapid on/off/on results in final server state `true` and ≤ 2 requests in order; offline; cache-first load; empty state; revision change triggers refetch).

### CREATE Features/ListingManagement/MyListingsView.swift + MyListingRow.swift
- **IMPLEMENT**: `NavigationStack` (Listings tab) → `List` of `MyListingRow` (cover photo with placeholder, street display, spot type badge, "$8/hr", `StatusBadge`-style "Active"/"Paused" — icon + text, not color only, and a `Toggle` labelled "<street> active"). Toolbar "+" (opens plan 07 `ListingWizardView` as `fullScreenCover`), pull-to-refresh, swipe actions (Delete destructive, Edit), context menu. Empty state: `EmptyStateView(icon: "parkingsign.circle", title: "No listings yet", message: "List your driveway or garage…", action: "Create listing")`. Loading skeleton via `.redacted`. Error state: `ErrorBanner` with Retry above cached content. Row taps push `ListingDetailManageView`.
- **PATTERN**: `swiftui-development` list + accessibility; `.scrollContentBackground(.hidden)` on brand ivory.
- **GOTCHA**: 44pt row minimum; VoiceOver: combine row into one element with custom actions ("Toggle active", "Edit", "Delete") and keep the Toggle reachable (`accessibilityElement(children: .contain)`).
- **VALIDATE**: build; previews (empty, loaded, offline banner, XXL).

### CREATE Features/ListingManagement/ListingDetailManageView(+ViewModel).swift
- **IMPLEMENT**: Read-only summary as drivers see it (plan 07 `PreviewStepView` content reused, label "Drivers see this"), host-only extras: active switch (same optimistic logic via shared `ListingActivationController` helper used by the list VM and this VM — extract to avoid duplication), "Edit listing", "Blocked dates (N)", "Delete listing" (destructive, separated at bottom). Shows `active == false` banner "Paused — drivers can't see this listing."
- **VALIDATE**: `MyListingsViewModelTests` shared controller cases; previews.

### CREATE Features/ListingManagement/BlockedDatesEditorView + BlockedDatesViewModel
- **IMPLEMENT**: `MultiDatePicker("Blocked dates", selection: $selection, in: Date.now...)` bound to `Set<DateComponents>` built with a New York calendar (`Calendar(identifier: .gregorian)` with `timeZone = America/New_York`). VM converts to/from sorted `["yyyy-MM-dd"]` strings (`en_US_POSIX`), drops past dates on load (they are meaningless; note "Past dates removed") and keeps them out of the PATCH; dirty tracking; Save calls `update(id:, patch: ListingPatch(blockedDates:))` (replace-all); list beneath the calendar with per-date remove buttons ("Remove June 15") for accessibility since calendar multi-select is hard for VoiceOver; "Clear all" with confirmation. Cap: none defined (Open Question 4); guard at 366 dates.
- **GOTCHA**: The contract has no blocked-dates endpoint; assume `PATCH /listings/:id` with `blocked_dates` (Open Question 3). Blocking a date that already has pending/confirmed bookings: server behavior unspecified — client shows an inline note "Existing bookings on these dates aren't cancelled" only if confirmed (Open Question 5); do not promise it. Concurrent edit from another device: last-write-wins; refetch after save replaces local state. Device time zone ≠ NY must not shift dates (use NY calendar in both directions; test at UTC-8 and UTC+9).
- **VALIDATE**: `… -only-testing:SpotiqueTests/BlockedDatesViewModelTests` (round trip, sorting, dedupe, past-date pruning, time-zone independence, PATCH body has only `blocked_dates`, add/remove, discard without save).

### CREATE Features/ListingManagement/ListingEditView + ListingEditViewModel
- **IMPLEMENT**: `Form` with sections reusing plan 07 step content views bound to `ListingFormModel(editing: listing)` (add this initializer in plan 07's file — coordinate; if 07 not yet landed, the initializer is added by 08 in an extension in `Features/ListingManagement/ListingFormModel+Editing.swift`): Address (shows current `displayAddress`; "Change address" reveals `AddressAutocompleteField`; changing requires new 11372 selection), Spot type, Photos (existing remote URLs + new picks; total 1–4; new ones processed and uploaded through `PhotoUploading`, existing kept as their URL strings), Rate, Schedule, Description, Payment, Blocked dates row (pushes `BlockedDatesEditorView`). Toolbar Cancel (dirty → discard confirmation) / Save (disabled until dirty and valid). `save()`: validate all sections, upload new photos (per-photo retry as in plan 07), build `ListingPatch.diff`, call `update`, on success `changeTracker.didChange()` + pop and update list via `didEdit`. 422 `details` mapped to field rows; 403/404 → dismiss with message and refresh (listing deleted elsewhere).
- **PATTERN**: plan 07 wizard VM error mapping and validators (same `ListingValidators`, no duplicates).
- **GOTCHA**: Editing an *active* listing is live immediately; show a one-line footer "Changes apply right away." Editing rate/schedule does not alter existing confirmed bookings (server concern; no client promise). If the owner response lacks `address`, address unchanged ⇒ omit `address/lat/lng` from the patch.
- **VALIDATE**: `… -only-testing:SpotiqueTests/ListingEditViewModelTests` (no-op edit sends nothing; only changed fields sent; invalid rate blocked; removing last photo blocked; last enabled day removal blocked; description cleared → `""`; photo upload failure keeps form and retries; 422 mapping; dirty-discard flow).

### CREATE Services/ActiveBookingChecking.swift + Features/ListingManagement/DeleteListingConfirmation.swift
- **IMPLEMENT**: `protocol ActiveBookingChecking: Sendable { func activeBookingCount(forListing id: String) async throws -> Int }`. Live: `GET /bookings?role=host&status=pending` and `…status=confirmed` (per_page 50, all pages), filtered client-side by `listingId`; sums. (May later delegate to plan 06/09's `BookingServicing`; keep as a thin protocol so the swap is one file.) `DeleteListingConfirmation.make(activeCount: Int?) -> Content` returns: `count > 0` → title "Delete this listing?", message **"Are you sure? Pending bookings will be cancelled."** (verbatim PRD), destructive "Delete Listing", cancel "Keep Listing"; `count == 0` → message "Are you sure? This can't be undone."; `nil` (check failed/offline) → the verbatim PRD sentence as the safe default. Flow: tap Delete → show a progress "Checking bookings…" (max ~2 s, non-blocking timeout → nil) → present `confirmationDialog` → `confirmDelete()` → `delete(id:)` → remove row, `changeTracker.didChange()`, `OwnListingCache` update, dismiss detail.
- **GOTCHA**: Contract doesn't give per-listing counts; proposing an owner-side `active_bookings_count` on the listing object would remove the extra request (Open Question 2). Confirmed bookings also count (contract cancels "pending or confirmed"), although the PRD sentence names only "Pending". Delete is not idempotent: a 404 after retry is treated as success. Never optimistic-remove before confirmation returns; rollback not needed since removal happens on success (list shows a spinner on that row meanwhile).
- **VALIDATE**: `… -only-testing:SpotiqueTests/DeleteListingConfirmationTests` (exact copy string equality for the three cases; checker failure → default; count sums pending+confirmed for the right listing; 204 removes row; failure keeps row + banner).

### UPDATE App/RootView / MainTabView: Listings tab; CREATE ActiveListingsSection
- **IMPLEMENT**: "Listings" tab (`NavigationStack(path:)`) shown only when `user.role ∈ {host, both}` (react to role change from plan 13 without relaunch). `ActiveListingsSection(listings:)` — compact read-only list of active listings for plan 13, taking data from `MyListingsViewModel`/service (no extra endpoint), each row navigates to `ListingDetailManageView`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build` + `AppRouterTests`.

### ADD change propagation + driver-map contract note
- **IMPLEMENT**: After any successful toggle/edit/delete/blocked-dates save call `listingChangeTracker.didChange()`. Plan 03's map refetches on `revision` change and on foreground. Also invalidate any client-side listing detail caches for that id (plan 04's `CachedListing`) via the same tracker (consumers evict by id — include `changedIds: Set<String>` alongside `revision` if plan 03/04 want it; add to tracker in one place).
- **GOTCHA**: "Disappear within 10 seconds" is enforced by API caching/visibility on `GET /listings`; the client's obligation is to (a) refetch on `revision`, (b) not serve stale map data older than the map's own refresh interval (plan 03 sets it ≤ 10 s while the map is visible? — confirm; a 10 s polling loop conflicts with battery: recommend refetch on foreground + on `revision` + pull, and let the server push notifications/next fetch cover other devices). Record in plan 03 Open Questions.
- **VALIDATE**: `MyListingsViewModelTests` (tracker bumped once per successful mutation, never on failure).

### CREATE localization + accessibility pass
- **IMPLEMENT**: All strings in `Localizable.xcstrings` (plural rules for "N blocked dates", "N listings"); VoiceOver labels: switch "Springfield St active, on/off" style ("74th Street listing, active, switch button"); calendar alternative list; delete dialog focus on title; Dynamic Type XXL rows stack vertically; contrast of paused state (icon + text).
- **VALIDATE**: build; manual VoiceOver.

---

## TESTING STRATEGY

### Unit Tests (Swift Testing; fakes; no network/sleep)
- **MyListingsViewModelTests**: load (loaded/empty/failed/offline-with-cache), optimistic toggle success + failure rollback, rapid toggling coalescing, per-listing isolation (toggling A doesn't affect B), pull-to-refresh, tracker revision refetch, sign-out clears cache.
- **ListingPatchEncodingTests**: minimal diffs; snake_case; description clearing; photos/blocked_dates full arrays; empty patch skipped.
- **ListingEditViewModelTests**, **BlockedDatesViewModelTests**, **DeleteListingConfirmationTests** as detailed above (exact PRD string `"Are you sure? Pending bookings will be cancelled."`).
- **ListingServiceManageTests** (`StubURLProtocol`): request method/path/body for update/toggle/delete/myListings; 204 handling; 403/404/422 mapping.

### Integration / UI
XCUITest later (plan 14): toggle a listing off in the fake environment and see "Paused"; delete flow shows dialog.

### Edge Cases
Toggle failing mid-flight then app backgrounded; editing a listing deleted elsewhere (404); role switched to driver while on the tab (tab disappears, state discarded); blocked dates across DST change (dates are calendar strings, unaffected); host deletes with 0 bookings; delete network failure; checker failure; two rapid delete taps; listing with no photos in stale data (placeholder); very long descriptions/street names at XXL; cache present but token expired (401 → sign-out clears cache); toggling the same listing from two devices (last write wins, next refetch reconciles).

## VALIDATION COMMANDS (from `iOS/`)
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/MyListingsViewModelTests -only-testing:SpotiqueTests/ListingEditViewModelTests -only-testing:SpotiqueTests/BlockedDatesViewModelTests -only-testing:SpotiqueTests/DeleteListingConfirmationTests -only-testing:SpotiqueTests/ListingPatchEncodingTests -only-testing:SpotiqueTests/ListingServiceManageTests`
### Level 3: Full suite
Same command without `-only-testing`.
### Level 4: Manual
Against the fake environment (and Rails when available): toggle off → row shows Paused, map (plan 03) drops the pin on next refetch; edit rate/photos/schedule; block two dates and verify the strings sent; delete with and without pending bookings; airplane mode toggle → rollback + banner; VoiceOver and XXL passes.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | No "my listings" endpoint; must include inactive listings and (ideally) `address` for the owner. `GET /listings?mine=true` vs `GET /users/me/listings`? | README gap 4 | Pending; client assumes `?mine=true`, one-line switch |
| 2 | No booking counts on listings; add `active_bookings_count`? Until then client uses `GET /bookings?role=host&status=…` | PRD §4.2, contract | Pending |
| 3 | Blocked dates: confirm `PATCH /listings/:id` with `blocked_dates` (full replacement) and `yyyy-MM-dd` NY dates; no dedicated endpoint | Contract | Assumed |
| 4 | Max number of blocked dates / how far ahead? | Discovered | Pending (client cap 366) |
| 5 | Blocking a date with existing bookings: rejected, allowed, or cancels them? | Discovered | Pending |
| 6 | Does deactivating a listing affect existing pending/confirmed bookings? Offline toggles queued or blocked? | PRD §4.2 | Assume no effect; blocked offline |
| 7 | Multiple listings per host? | PRD §8 Q4 | Assume allowed (list, not single detail) |
| 8 | Delete confirmation wording when no bookings exist / for confirmed bookings (PRD only defines pending sentence) | PRD §4.2 | Use verbatim sentence when count > 0 or unknown |
| 9 | Server guarantee for 10 s disappearance (cache TTL, notification/push, polling)? | PRD §4.2 | Server; client refetches on change/foreground |
| 10 | Does PATCH re-check the 11372 rule and duplicate warning on address change? | Contract | Assume yes; handle `meta.warnings` like plan 07 |

## ACCEPTANCE CRITERIA
- [ ] Listings tab (host/both only) shows the host's listings, including inactive, with cached content offline
- [ ] Single switch toggles active/inactive optimistically; failures roll back visibly and are announced
- [ ] Any listing field is editable using plan 07's validators; only changed fields are PATCHed
- [ ] Blocked dates can be added/removed via calendar and via an accessible list; sent as NY `yyyy-MM-dd` strings
- [ ] Delete requires confirmation; with active bookings (or unknown) the exact text "Are you sure? Pending bookings will be cancelled." is shown
- [ ] After toggle/edit/delete the map/list refetch immediately (10 s disappearance is server-side and documented)
- [ ] No full address in the cache or logs; sign-out clears own-listing cache
- [ ] VoiceOver, Dynamic Type, 44pt targets, localization complete
- [ ] All validation commands pass; no regressions; `docs/api-contract.md` updated for owner listing endpoint, booking counts, blocked-dates semantics

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Open questions 1–3 resolved or recorded with assumptions
- [ ] Plan 13 can embed `ActiveListingsSection`

## NOTES
- `ListingServicing` growth is split across `+Create`/`+Manage` extension files and `MARK` blocks to keep 03/07/08 merges conflict-free.
- Deactivating (pause) versus deleting is deliberately cheap and reversible; delete is the only destructive action and the only one needing a pre-flight bookings check.
- The optimistic toggle uses server response as source of truth to avoid drift; coalescing prevents out-of-order responses flipping the switch.
- Default MainActor isolation: `ListingPatch`, date helpers, and confirmation copy builder are `nonisolated`/pure for direct testing.
