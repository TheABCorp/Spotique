# Feature: Host — Create a Parking Spot Listing (Wizard, Places Autocomplete, Photos, Schedule)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities (defined in `01-foundation.md`), and import from the right files. Do not redefine anything owned by plans 01/03.

**Source:** `docs/prd-v1.md` §4.2 "P0 — Create a Parking Spot Listing", §6.1 (Host Onboarding & Listing Flow), §7.2/§7.3/§7.4, §8 Q4; `docs/api-contract.md` "Listings → `POST /listings`", "Users → `PATCH /users/me`", "Error Format"; `iOS/plans/README.md` gaps 4 and 6.

## Feature Description

A multi-step wizard that lets a host publish a spot: Address (Google Places Autocomplete restricted to 11372) → Spot type → Photos (1–4, compressed client-side) → Hourly rate (whole dollars $5–$50) → Weekly availability → Description (optional, ≤ 200) → Payment info text → Preview (exactly what drivers see; street name only) → Publish. Listing is active immediately. Draft survives backgrounding and app kill. Also delivers the reusable `AddressAutocompleteField`, the `PlacesService`, the `ImageProcessing` utility, and the reusable step/form components that plan 08 reuses as its edit form.

## User Story

As a host (Maria), I want to list my driveway or garage in a few guided steps, so that drivers nearby can find and request it and I can earn money from an unused spot.

## Problem Statement

Without listing creation there is no supply. Hard parts: getting a verified, in-neighborhood address with coordinates; keeping photo payloads small and free of location metadata; a weekly schedule editor that cannot produce invalid data; and not losing a half-finished 9-step form.

## Solution Statement

`ListingFormModel` (draft + validators, shared with plan 08) driven by `ListingWizardViewModel` (step state, back/next). `PlacesService` behind `PlacesServicing` wraps the Google Places SDK (bounds restriction + post-resolution postal-code check, session tokens, debounced typing). `ImageProcessing` (ImageIO, `@concurrent`) downsamples and re-encodes JPEG with a size-verification loop, dropping all EXIF/GPS. Uploading sits behind `PhotoUploading` (base64 data-URI default; presigned-URL implementation ready) because the contract is ambiguous. The draft is persisted to a protected JSON file (photos as files) on every step change and on `scenePhase == .background`. Publishing calls `ListingServicing.create(_:)`; on success a `ListingChangeTracker` bump makes the map (plan 03) and "Listings" tab (plan 08) refetch immediately.

## Requirements & Acceptance Criteria

**PRD §4.2 required fields (verbatim):** Street address (Google Places Autocomplete, restricted to zip code 11372); Spot type: Driveway or Garage; Photos: 1–4 photos, minimum 1 required; Hourly rate: whole dollars only, minimum $5, maximum $50; Weekly availability schedule: per-day toggle (on/off) with start and end time; Optional description (max 200 characters); Preferred payment method display text (e.g. "Cash or Venmo @hostname").

**PRD acceptance criteria (verbatim):**
- Address field uses Google Places Autocomplete; GPS coordinates extracted and stored
- Photos compressed client-side before upload (max 800 KB per image, JPEG quality 0.7)
- Listing saved to Firestore as active immediately on creation
- Host sees their pin appear on the map within 30 seconds
- Duplicate listings at the same address are flagged with a warning (not blocked)

**PRD §6.1:** wizard order Address → Spot type → Photos → Hourly rate → Availability schedule → Description (optional) → Payment info → Preview → Publish; then "Listing live: host sees their pin on the map; inbox tab shows 0 pending requests".

**Contract validations (`POST /listings`):** `address` in zip 11372 (duplicate = warning, not block); `spot_type` ∈ {driveway, garage}; `photos` 1–4; `hourly_rate_cents` 500–5000 whole dollars; `description` ≤ 200, optional; `availability_schedule` at least one day enabled. Errors: 422 `validation_failed` with `details`; 403 `forbidden` (non-host).

**Derived client rules:** schedule times "HH:mm" interpreted in `America/New_York`, `end > start` same day (no overnight); payment text required (PRD lists it under required fields) — max length 60 (proposed, see Open Questions).

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: High
**Platforms**: iOS (API endpoint exists in contract, not yet in `Api/`; build against `FakeListingService`)
**Primary Systems Affected**: `Features/ListingCreation/`, `Services/{Places,Listing,PhotoUpload,ListingDraft}Service`, `Core/Images/ImageProcessing`, `AppEnvironment`, `Info.plist`/SPM
**Dependencies**: Google Places SDK for iOS (SPM `https://github.com/googlemaps/ios-places-sdk`, product `GooglePlaces`), PhotosUI (`PhotosPicker`), ImageIO. Plan 01 (models, APIClient, components), plan 02 (signed-in host).

**Ordering:** may start after 01 + 02; does **not** need plan 03's map — only `Services/ListingService.swift` and `Models/Listing.swift`. Plan 03 also adds the Google **Maps** SDK; 07 adds only the **Places** SDK package. If both are merged into the pbxproj, add each package via its own commit to avoid `project.pbxproj` conflicts (package references are the only pbxproj edit; source files are auto-synced).

**Merge-conflict protocol (03 ↔ 07 ↔ 08):**
- `Services/ListingService.swift` — whichever of 03/07 lands first creates the file with `ListingServicing` + `LiveListingService`; the second only appends. Method ownership: **03** `listings(query:)`, `listing(id:)`; **07** `create(_:) -> CreateListingResult`; **08** `update(id:patch:)`, `toggleActive(id:active:)`, `delete(id:)`, `myListings()`. Put each plan's requirements under its own `// MARK: – Plan 0N` block in the protocol, and put each plan's Live implementations in `LiveListingService+Create.swift` (07) / `+Manage.swift` (08) extensions (extension methods fulfilling protocol requirements are legal), so diffs never touch the same lines.
- `FakeListingService` (tests): same ownership; each plan adds its stubs/recorded-call arrays; unimplemented stubs return `.failure(.unknown)`.
- `AppEnvironment` — 03 adds `listingService`; 07 adds `placesService`, `photoUploader`, `draftStore`, `listingChangeTracker`; 08 adds nothing new (or `activeBookingChecker`). One property per line, alphabetical, to keep rebases trivial. If 07 lands first it adds `listingService` and 03 keeps it.

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
(All planned in `01-foundation.md`; nothing exists yet but the template.)
- `iOS/Spotique/Core/Networking/{APIClient,Endpoint,APIError,JSONCoding}.swift` — `send`, `.validation(message:fields:)`, `.forbidden`, snake-case coding.
- `iOS/Spotique/Models/Listing.swift`, `Enums.swift` — `Listing`, `DaySchedule`, `SpotType`; `Weekday` keyed schedule.
- `iOS/Spotique/App/AppEnvironment.swift` — service registration (one property + one fake).
- `iOS/Spotique/Core/DesignSystem/Components/{PrimaryButton,SecondaryButton,Card,ErrorBanner,LoadingOverlay}.swift`.
- `iOS/Spotique/Core/Auth/SessionStore.swift` — `currentUser`, `update(user:)`, role gating.
- `iOS/Spotique/Services/UserService.swift` — `update(_:)` for saving default payment text.
- `iOS/SpotiqueTests/Fakes/StubURLProtocol.swift`, `Fixtures/listing.json`.
- `iOS/CLAUDE.md` — file size ≤ ~300 lines, functions ≤ ~30 lines, no force unwrap, `os.Logger`.

### New Files to Create
```
iOS/Spotique/Features/ListingCreation/ListingWizardView.swift            container: progress, back/next, fullScreenCover host
iOS/Spotique/Features/ListingCreation/ListingWizardViewModel.swift
iOS/Spotique/Features/ListingCreation/ListingFormModel.swift             @Observable draft + validation, shared with plan 08
iOS/Spotique/Features/ListingCreation/ListingDraft.swift                 Codable draft value + Step enum + ScheduleDraft
iOS/Spotique/Features/ListingCreation/ListingValidators.swift            pure nonisolated validators
iOS/Spotique/Features/ListingCreation/Steps/{AddressStepView,SpotTypeStepView,PhotosStepView,RateStepView,ScheduleStepView,DescriptionStepView,PaymentStepView,PreviewStepView,PublishStatusView}.swift
iOS/Spotique/Features/ListingCreation/Components/{AddressAutocompleteField,AddressAutocompleteViewModel,DayScheduleRow,TimeOfDayPicker,PhotoGridView,WizardProgressHeader}.swift
iOS/Spotique/Services/PlacesService.swift                                PlacesServicing + LivePlacesService (Google SDK)
iOS/Spotique/Services/PhotoUploading.swift                               protocol + Base64PhotoUploader + PresignedPhotoUploader
iOS/Spotique/Services/ListingService.swift                               (shared with 03; see protocol above) + LiveListingService+Create.swift
iOS/Spotique/Services/ListingDraftStore.swift                            protocol + FileListingDraftStore
iOS/Spotique/Services/ListingChangeTracker.swift                         @Observable revision counter
iOS/Spotique/Core/Images/ImageProcessing.swift
iOS/Spotique/Models/{NewListingRequest,AddressSelection,CreateListingResult}.swift
iOS/SpotiqueTests/Fakes/{FakePlacesService,FakePhotoUploader,FakeListingDraftStore}.swift  (+ FakeListingService create stubs)
iOS/SpotiqueTests/Fixtures/{listing-create-201.json,listing-create-201-duplicate.json,error-listing-validation.json}
iOS/SpotiqueTests/{ListingValidatorsTests,ListingWizardViewModelTests,AddressAutocompleteViewModelTests,ImageProcessingTests,ListingServiceCreateTests,PhotoUploaderTests,ListingDraftStoreTests}.swift
```

### Documentation — READ BEFORE IMPLEMENTING
- [Places SDK for iOS (New) overview / autocomplete](https://developers.google.com/maps/documentation/places/ios-sdk/autocomplete) — programmatic `findAutocompleteSuggestions`/`AutocompleteRequest`, `AutocompleteFilter` (`locationRestriction`, `regionCodes`, `types`), session tokens. **Gotcha:** Autocomplete cannot filter by postal code; restrict with a rectangular `locationRestriction` around 11372 and verify `postalCode` from place details after selection. Confirm exact symbol names against the SDK version resolved by SPM (the "New" API renamed `GMSPlacesClient` → `PlacesClient`).
- [Places SDK — Session tokens & billing](https://developers.google.com/maps/documentation/places/ios-sdk/session-tokens) — one token per typing session, ended by the details fetch (Place Details request with `addressComponents`, `coordinate`, `formattedAddress` only — request minimum fields for cost).
- [Get an API key / restrict to iOS apps](https://developers.google.com/maps/documentation/ios-sdk/get-api-key) — restrict to bundle ID `com.actionman.Spotique`, API restriction = Places API (New) (+ Maps SDK for iOS shared with 03).
- [PhotosPicker](https://developer.apple.com/documentation/photokit/photospicker) — `selection: [PhotosPickerItem]`, `maxSelectionCount`, `matching: .images`, `loadTransferable(type: Data.self)`; no photo-library permission prompt needed.
- [CGImageSource thumbnails](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)) with `kCGImageSourceCreateThumbnailFromImageAlways`, `…WithTransform` (bakes orientation), `kCGImageSourceThumbnailMaxPixelSize`; [CGImageDestination](https://developer.apple.com/documentation/imageio/cgimagedestination) with `kCGImageDestinationLossyCompressionQuality`. Passing only that option (no source properties) writes no EXIF/GPS/TIFF dictionaries.
- `docs/api-contract.md` § Listings/`POST /listings`, § Users `PATCH /users/me`, § Error Format.

### Skills to Apply
`mvvm-architecture` (ViewModel/DI), `swiftui-development` (Form/FocusState/keyboards/accessibility/previews), `spotique-brand-ui` + `liquid-glass-design` (wizard chrome, floating Next bar), `swift-concurrency-6-2` (`@concurrent` image work; `nonisolated` models), `ios-api-client` (encoding, errors), `ios-security-review` (keys, EXIF, logging, file protection), `ios-performance` (image memory, downsampling), `swift-actor-persistence` (draft store as file-backed actor option).

### Patterns to Follow
- ViewModel: `@Observable @MainActor final class ListingWizardViewModel`, deps injected as protocols, `enum PublishState { idle, uploading(progress), submitting, failed(PublishFailure), published(Listing, warnings) }`.
- Pure validators are `nonisolated enum ListingValidators { static func rate(cents:) -> ValidationIssue? … }` (testable without MainActor).
- Error text via `APIError.errorDescription` (01); field errors from `.validation(fields:)` are mapped back to wizard steps (`address`→Address, `photos`→Photos, `hourly_rate_cents`→Rate, `availability_schedule`→Schedule, `description`→Description).
- Logging: `Log.ui`/`Log.network`; never log the address, coordinates, or photo bytes.

---

## PRIVACY & SECURITY

- The host's full street address and precise coordinates are sent to `POST /listings` (required) over HTTPS and are held only in the in-memory draft and the on-disk draft file. The listing model returned by the API for drivers carries `display_address` only; this plan's UI (Preview) renders only a street-name display string and never the house number. No full address in logs, analytics, or any driver-facing cache (SwiftData `CachedListing` is plan 03's and stores no `address`).
- **Draft file**: `Application Support/ListingDraft/` with `FileProtectionType.completeUntilFirstUserAuthentication`, `isExcludedFromBackup = true`; deleted on publish success, explicit "Discard draft", and `SessionStore.signOut()` (register with the sign-out clean-up list). Draft contains the host's own address; this is why it is not in `UserDefaults`.
- **EXIF/GPS**: all picked images are re-encoded through ImageIO with no source properties copied — verified in `ImageProcessingTests` by reading back `CGImageSourceCopyPropertiesAtIndex` and asserting no `{GPS}`, `{Exif}`, `{TIFF}` (make/model) dictionaries. Never upload the original `Data`.
- **Places key**: stored in an xcconfig-injected `GOOGLE_PLACES_API_KEY` Info.plist value (not committed for prod; Debug key in a git-ignored `Secrets.xcconfig`); restricted server-side to bundle ID `com.actionman.Spotique` + Places API only; never logged. `PlacesClient.provideAPIKey` is called once at app start in `AppEnvironment.live` (shared with plan 03's Maps key call site).
- Only the host role can create (server returns 403 `forbidden`); client hides entry points unless `user.role` ∈ {host, both}. No third-party analytics.
- **Contract privacy concern (report):** `GET /listings` returns exact `latitude`/`longitude` to drivers; a precise pin on a driveway reveals the address. Recommend the server return coordinates jittered/rounded to ~150 m for non-confirmed callers. Client sends exact coordinates on create either way.
- Places autocomplete text sent to Google contains partial addresses of the *host* only (fine, host consents by using the feature); PhotosPicker grants access only to selected assets.

## IMPLEMENTATION PLAN

### Phase 1: Foundation — models, validators, image pipeline, draft store
`ListingDraft`, `ListingValidators`, `ImageProcessing`, `NewListingRequest`, `ListingDraftStore`, service protocol additions, fakes/fixtures.
### Phase 2: Core — Places + form components
`PlacesService`, `AddressAutocompleteField`/VM, `DayScheduleRow`, `PhotoGridView`, individual step views, `ListingFormModel`.
### Phase 3: Integration — wizard, publish, refresh, entry points
`ListingWizardViewModel/View`, `PhotoUploading`, publish flow with partial-failure retry, `ListingChangeTracker`, `AppEnvironment` wiring, entry point from plan 08's empty state / post-profile CTA (§6.1 "Create listing CTA"), map refresh hook.
### Phase 4: Testing & Validation
Unit tests, manual pass (simulator + device for real Places), accessibility pass.

---

## STEP-BY-STEP TASKS

### ADD Google Places SDK package
- **IMPLEMENT**: Add SPM dependency `googlemaps/ios-places-sdk` (product `GooglePlaces`) to the Spotique target; add `GOOGLE_PLACES_API_KEY` to xcconfig + `Info.plist` key; document the Cloud console restrictions in NOTES.
- **GOTCHA**: pbxproj is the one file that conflicts with plan 03 (Maps SDK); land package additions in separate small commits.
- **VALIDATE**: `cd iOS && xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE Models/{NewListingRequest,AddressSelection,CreateListingResult}.swift
- **IMPLEMENT**: `nonisolated struct NewListingRequest: Encodable, Sendable { let listing: Body }` with `Body{address, latitude, longitude, spotType, hourlyRateCents, description?, photos:[String], availabilitySchedule:[String: DaySchedule], paymentMethodText}`; disabled days encode `{ "enabled": false }` only (`encodeIfPresent`). `AddressSelection{ formattedAddress, latitude, longitude, postalCode, streetDisplay }` (Codable for the draft). `CreateListingResult{ listing: Listing, warnings: [ListingWarning] }`, `ListingWarning.duplicateAddress`.
- **PATTERN**: plan 01 `JSONCoding.encoder` (`.convertToSnakeCase`).
- **GOTCHA**: `convertToSnakeCase` also transforms dictionary keys; weekday names are single lowercase words so safe — assert in test. Empty description → omit (`nil`), not `""`.
- **VALIDATE**: `xcodebuild … test -only-testing:SpotiqueTests/ListingServiceCreateTests`

### CREATE Features/ListingCreation/ListingDraft.swift, ListingValidators.swift
- **IMPLEMENT**: `ListingDraft: Codable` {address: AddressSelection?, spotType?, photos:[DraftPhoto] (id, fileName, byteCount, uploadedURL?), rateDollars:Int? , schedule:[Weekday: DayScheduleDraft{enabled, startMinutes, endMinutes}], description, paymentText, currentStep, savedAt}. `Step: Int, CaseIterable` (address, spotType, photos, rate, schedule, description, payment, preview). Validators (all pure): `address(_:)` (non-nil and `postalCode == "11372"`), `photos(count:)` 1…4, `rate(dollars:)` 5…50 integer, `schedule(_:)` ≥1 enabled and each enabled day `end > start`, `description(_:)` ≤ 200 (count Characters, not UTF-16), `payment(_:)` non-empty trimmed ≤ 60. Each returns `ValidationIssue?` with a localized message key and the field it belongs to.
- **GOTCHA**: `hourly_rate_cents = dollars * 100` computed in one place (`ListingDraft.hourlyRateCents`). Default rate for the stepper starts at $10 (UI default only, not a product decision).
- **VALIDATE**: `… -only-testing:SpotiqueTests/ListingValidatorsTests`

### CREATE Core/Images/ImageProcessing.swift
- **IMPLEMENT**: `enum ImageProcessing { @concurrent static func prepareJPEG(from data: Data, maxBytes: Int = 800_000, maxDimension: CGFloat = 2048, startQuality: CGFloat = 0.7) async throws -> ProcessedPhoto }`. Steps: create `CGImageSource`; thumbnail at `maxDimension` with transform; encode JPEG at quality 0.7 via `CGImageDestination` (no metadata); if `> maxBytes`, loop: quality −0.1 down to 0.4, then scale `maxDimension` ×0.8 and reset quality, up to 8 iterations; throw `ImageError.cannotMeetLimit` / `.unreadable`. `ProcessedPhoto{ id, data, pixelSize }` `Sendable`.
- **PATTERN**: `swift-concurrency-6-2` `@concurrent` example; `ios-performance` (downsample, never decode full-size bitmap).
- **GOTCHA**: PRD says "max 800 KB… quality 0.7" — 0.7 is the *starting* quality; the loop guarantees the byte cap. Define 800 KB as 800 × 1000 (conservative) . HEIC/PNG/live-photo inputs all flow through ImageIO. `@concurrent` requires the function be `nonisolated` and args `Sendable`.
- **VALIDATE**: `… -only-testing:SpotiqueTests/ImageProcessingTests`

### CREATE Services/ListingDraftStore.swift
- **IMPLEMENT**: `protocol ListingDraftStoring: Sendable { func load() async -> ListingDraft?; func save(_:) async; func writePhoto(id:data:) async throws; func photoData(id:) async -> Data?; func clear() async }` and `FileListingDraftStore` (actor; JSON `draft.json` + `photos/<id>.jpg`; attributes per PRIVACY). Corrupt/undecodable JSON → discard silently.
- **PATTERN**: `swift-actor-persistence` skill.
- **VALIDATE**: `… -only-testing:SpotiqueTests/ListingDraftStoreTests` (temp-directory injected)

### CREATE Services/PlacesService.swift
- **IMPLEMENT**: `protocol PlacesServicing: Sendable { func suggestions(for query: String, token: PlacesSessionToken) async throws -> [AddressSuggestion]; func resolve(_ s: AddressSuggestion, token: PlacesSessionToken) async throws -> AddressSelection; func newSessionToken() -> PlacesSessionToken }`. Live: `locationRestriction` rectangle (SW ≈ 40.7440,-73.8985 / NE ≈ 40.7610,-73.8690 — approximate superset of 11372; verify against the ZIP boundary), `regionCodes ["US"]`, `types [.address]`; resolve fetches `addressComponents`, `coordinate`, `formattedAddress`; rejects when `postal_code != "11372"` → `PlacesError.outsideServiceArea`; derives `streetDisplay` from the `route` component (+ ", Jackson Heights") never the `street_number`. Errors: `noResults` (empty list, not an error), `outsideServiceArea`, `quotaExceeded`/`unavailable` (map `OVER_QUERY_LIMIT`/network), `offline`, `cancelled`.
- **GOTCHA**: SDK calls are callback/async from Google; wrap so results arrive on MainActor; `AddressSuggestion`/`PlacesSessionToken` are our own `Sendable` structs so the ViewModel never imports `GooglePlaces` (keeps tests SDK-free). Bounds are a *bias-free hard restriction*, so a street that spans zip boundaries can still slip through — the post-resolution check is authoritative and the server re-validates.
- **VALIDATE**: build; `AddressAutocompleteViewModelTests` uses `FakePlacesService`.

### CREATE Components/AddressAutocompleteField.swift + AddressAutocompleteViewModel.swift
- **IMPLEMENT**: Reusable, coupled to nothing but `PlacesServicing`: `AddressAutocompleteField(selection: Binding<AddressSelection?>, placesService:)`. VM state: `query`, `phase: idle | searching | results([AddressSuggestion]) | noResults | outsideArea | quota | offline | resolving | selected(AddressSelection)`. Debounce 300 ms via a cancellable `Task` using an injected `Clock`; min 3 characters; cancel in-flight on each keystroke; one session token per query session, renewed after `resolve` or after the field is cleared. Selecting a suggestion shows a confirmed row with a "Change" button (edits clear `selection`). Text field: `.textContentType(.fullStreetAddress)`, `.textInputAutocapitalization(.words)`, `.autocorrectionDisabled()`, results in an inline list below (not a popover) with 44pt rows and `accessibilityLabel` = suggestion text; announce result count via `AccessibilityNotification.Announcement`. Attribution: the required "Powered by Google" element per Places terms.
- **GOTCHA**: Do not put the plan-02 home-address field on this component — plan 02 uses a plain `TextField`. Error copy: outside → "Spotique is only available in Jackson Heights (11372) right now."; no results → "No matching addresses. Include the street number."; quota/unavailable → "Address search is unavailable. Try again shortly." + Retry; offline → "You're offline. Connect to search addresses."
- **VALIDATE**: `… -only-testing:SpotiqueTests/AddressAutocompleteViewModelTests`

### CREATE Components/{DayScheduleRow,TimeOfDayPicker}.swift + Steps/ScheduleStepView.swift
- **IMPLEMENT**: Seven rows Monday–Sunday. Each: `Toggle` (label "Monday", `accessibilityHint` "Available for booking"), and when on, two `TimeOfDayPicker`s (Start / End) with 15-minute granularity. Inline validation under the row: "End time must be after start time." plus a footer "At least one day must be available." Default when enabling a day: 09:00–17:00. Convenience "Copy to all days" / "Weekdays" chips are optional.
- **GOTCHA**: Times are wall-clock strings in `America/New_York` regardless of device time zone → the picker binds to minutes-since-midnight (`Int`) and formats "HH:mm" with `Locale(identifier: "en_US_POSIX")`; if a `DatePicker` is used, build it with a `Calendar` whose `timeZone` is New York and `.environment(\.timeZone, …)`. Emit `"HH:mm"` (24 h) irrespective of the device's 12/24-hour setting. No DST math is done client-side (strings are wall time); 02:00–03:00 on DST days is a server concern — note. Overnight windows (e.g. 22:00–02:00) are **not** representable (`end > start` only): show helper "Need to cross midnight? Set the day to end at 11:45 PM and enable the next day from 12:00 AM." Latest end = 23:45 (avoids "24:00"). Removing the last enabled day: toggle is allowed but Next is disabled and the footer error appears; never silently re-enable.
- **VALIDATE**: `ListingValidatorsTests` schedule cases; `#Preview` with XXL Dynamic Type (rows must wrap vertically, not truncate).

### CREATE Components/PhotoGridView.swift + Steps/PhotosStepView.swift
- **IMPLEMENT**: `PhotosPicker(selection:, maxSelectionCount: 4 - photos.count, matching: .images)`; on selection load `Data` (`loadTransferable`), call `ImageProcessing.prepareJPEG`, write to the draft store, append `DraftPhoto` with `state: processing | ready | failed(reason)`. Grid with per-tile remove ("Remove photo 2 of 3" VoiceOver label), reorder via move-left/right actions (first photo = cover; announce), count caption "2 of 4 photos". Min 1 enforced by validator. Failed tile shows a retry/remove.
- **GOTCHA**: Process in a `TaskGroup` limited to 2 concurrent to bound memory; drop the `PhotosPickerItem` selection after import so it can be re-used. Cancel work when the wizard is dismissed.
- **VALIDATE**: `ImageProcessingTests` (≤ 800_000 bytes for a 4000×3000 synthetic image with noise; metadata absent; orientation baked in); manual pick of a geotagged photo.

### CREATE Steps/{SpotType,Rate,Description,Payment}StepView.swift
- **IMPLEMENT**: SpotType — two large selectable cards (Driveway/Garage) with icon+text, `accessibilityAddTraits(.isSelected)`. Rate — `Stepper` in whole dollars with large "$10 / hour" label, `accessibilityValue("10 dollars per hour")`, range 5…50, helper "Whole dollars, $5–$50." Description — `TextEditor` with live counter "43 / 200" (also VoiceOver "43 of 200 characters"); block typing past 200 (truncate paste). Payment — `TextField` prefilled from `sessionStore.currentUser?.paymentMethodText`, placeholder "Cash or Venmo @yourname", `.submitLabel(.done)`, toggle "Use this for future listings" → `UserServicing.update` (PATCH `/users/me` `payment_method_text`) after successful publish only.
- **PATTERN**: `swiftui-development` Form + `@FocusState` enum (`.description`, `.payment`), focus moves on step appear; keyboard toolbar "Done".
- **VALIDATE**: build; ViewModel tests below.

### CREATE Features/ListingCreation/ListingFormModel.swift
- **IMPLEMENT**: `@Observable @MainActor final class ListingFormModel` owning `draft`, `issues: [Step: ValidationIssue]`, `func validate(_ step:)`, `var isPublishable`, `func toRequest(photoURLs:) -> NewListingRequest`. Exposes no navigation. Shared unchanged with plan 08's edit form (which initializes it from a `Listing` via `init(editing:)` added by plan 08).
- **GOTCHA**: Keep this file free of wizard navigation so plan 08 can import it without pulling `Step` order.
- **VALIDATE**: `ListingWizardViewModelTests`

### CREATE Features/ListingCreation/ListingWizardViewModel.swift + ListingWizardView.swift
- **IMPLEMENT**: Observable state: `currentStep`, `form`, `canGoBack`, `canAdvance` (= `form.validate(currentStep) == nil`), `showsValidation` (errors appear after first failed Next or field blur, never on first appearance), `publishState`, `restoredDraftBanner`. Actions: `next()`, `back()` (never loses data), `jump(to:)` from Preview's per-section "Edit" buttons (returns to Preview afterward), `saveDraft()`, `discardDraft()`, `publish()`. Persistence: save after each step change + `.onChange(of: scenePhase)` `.background/.inactive`; on init load draft → offer "Continue where you left off / Start over". Navigation: `ListingWizardView` presented `fullScreenCover`; toolbar Close (confirmation "Save draft / Discard"), Liquid Glass bottom bar with Back/Next (PrimaryButton, ≥44pt, disabled with reason readout), header `WizardProgressHeader` "Step 3 of 8" (`accessibilityValue`), `ProgressView`. Interactive swipe-dismiss disabled (`.interactiveDismissDisabled(form.isDirty)`).
- **PATTERN**: `mvvm-architecture` state-enum + `NavigationStack` with typed `Step` path.
- **GOTCHA**: Steps must not be skippable via `jump` past the first invalid step. Photos are stored on disk so restored drafts keep them.
- **VALIDATE**: `… -only-testing:SpotiqueTests/ListingWizardViewModelTests`

### CREATE Steps/PreviewStepView.swift
- **IMPLEMENT**: Renders the listing exactly as drivers see it: gallery (local processed images, cover first), `streetDisplay` (never house number) as the address line, spot type, `$X/hr`, description, weekly availability summary, host display name "First L" + placeholder rating ("New host"), payment text. Uses plan-01 `Card`, and plan 03/04's `ListingPreviewCard`/gallery if merged (otherwise local minimal views with `// TODO(plan04): swap`). Section "Edit" buttons jump back. Label under the address: "Drivers see only the street name until they're confirmed." Shows `PublishStatusView` on publish.
- **GOTCHA**: `display_address` is authoritative from the server; the preview string is a best-effort of the same rule (route + neighborhood). Do not show the full address anywhere in this view except a host-only "Your address (private)" row that is visually distinct and excluded from screenshots' accessibility "driver preview" label.
- **VALIDATE**: `#Preview` light/dark/XXL; snapshot by eye.

### CREATE Services/PhotoUploading.swift
- **IMPLEMENT**: `protocol PhotoUploading: Sendable { func upload(_ photo: ProcessedPhoto) async throws -> String }` (returns the value that goes in `photos[]`). `Base64PhotoUploader`: returns `"data:image/jpeg;base64,<…>"` (no network, cannot partially fail; body ≤ ~4.3 MB for 4 photos). `PresignedPhotoUploader`: `POST /uploads` (proposed; not in contract) → `{upload_url, public_url}`, `PUT` bytes with `Content-Type: image/jpeg`, returns `public_url`; per-photo retry with exponential backoff (max 3), only for idempotent PUT. Selected by one line in `AppEnvironment.live` (`photoUploader: Base64PhotoUploader()`).
- **GOTCHA**: Base64 vs raw base64 (no `data:` prefix) is also unspecified — see Open Questions; isolate in `Base64PhotoUploader.encode`. Partial failure handling lives in the ViewModel: per-photo `uploaded(String)` is stored in `DraftPhoto.uploadedURL` so a retry uploads only the failed ones and never re-uploads successes.
- **VALIDATE**: `… -only-testing:SpotiqueTests/PhotoUploaderTests` (StubURLProtocol for presigned; data-URI prefix/size for base64)

### ADD ListingServicing.create(_:) (+ LiveListingService+Create.swift, FakeListingService stub)
- **IMPLEMENT**: `func create(_ request: NewListingRequest) async throws -> CreateListingResult`; Live: `POST /listings` (`requiresAuth`), decodes `{data: Listing, meta: {warnings: ["duplicate_address"]}}`; if the API returns no `meta.warnings`, `warnings = []`.
- **GOTCHA**: The contract says duplicates "trigger a warning" but defines **no response field** — assume `meta.warnings` (Open Question 2). Not idempotent: no automatic retry; on timeout, do not blindly resubmit — refetch `myListings()` (plan 08) is not available yet, so show "Couldn't confirm. Check the Listings tab before trying again" and keep the draft with a client-generated `Idempotency-Key` header (ignored today; proposed).
- **VALIDATE**: `… -only-testing:SpotiqueTests/ListingServiceCreateTests` (request JSON equals contract example; 201 decode; 422 field mapping; 403; offline)

### CREATE Services/ListingChangeTracker.swift and wire refresh
- **IMPLEMENT**: `@Observable @MainActor final class ListingChangeTracker { private(set) var revision = 0; func didChange() }`. `publish()` success → `didChange()`. Plan 03's `MapViewModel` observes `revision` (and `scenePhase == .active`) to refetch listings without the user pulling to refresh; if plan 03 is not merged, leave a `// TODO(plan03)` and record in its plan. Plan 08's `MyListingsViewModel` does the same.
- **GOTCHA**: The "within 30 seconds" criterion: client refetches immediately after 201 (well < 30 s) and again on foreground; server must make the new listing visible to `GET /listings` promptly (no long caching). The host's own pin is an ordinary pin — no special local injection.
- **VALIDATE**: `ListingWizardViewModelTests` (`didChange` called once on success).

### UPDATE App/AppEnvironment.swift; ADD entry points
- **IMPLEMENT**: Properties `placesService`, `photoUploader`, `draftStore`, `listingChangeTracker` in live + preview factories (fakes in `.preview`). Entry points: (a) plan 08's "Listings" tab empty state and "+" toolbar button (`Features/ListingManagement`), (b) post-onboarding "Create listing" CTA for `role == host/both` (plan 02 hands off via `AppRouter`). Driver-only users never see the entry (plan 13's role toggle upgrades them).
- **VALIDATE**: `xcodebuild … build` and `AppRouterTests`.

### CREATE Localizable.xcstrings entries + accessibility pass
- **IMPLEMENT**: All wizard strings (step titles, validation messages, place errors, dialogs) in the catalog; plural variations for "photos" counts. Verify VoiceOver order on each step, Reduce Motion (no animated step transitions if enabled), Dynamic Type XXL previews, dark mode contrast.
- **VALIDATE**: `xcodebuild … build` (catalog compiles), manual VoiceOver run.

---

## TESTING STRATEGY

### Unit Tests (Swift Testing, `@MainActor` where needed, no network/sleep)
- **ListingValidatorsTests**: rate 4/5/50/51 dollars; description 200 vs 201 chars incl. emoji/combining marks; schedule none enabled, end == start, end < start, valid; photos 0/1/4/5; address postal 11373 rejected; payment empty/61 chars.
- **ListingWizardViewModelTests**: cannot advance with invalid step; Back preserves values; jump-back-from-Preview; restore draft from `FakeListingDraftStore`; save on step change; publish happy path (photos uploaded → create → `didChange` → draft cleared); 422 maps `photos` error to Photos step; duplicate warning surfaced (`.published(_, warnings: [.duplicateAddress])`); photo partial failure retries only failed uploads; publish offline keeps draft; double-tap Publish is ignored (single request).
- **AddressAutocompleteViewModelTests**: debounce (test `Clock`), <3 chars no request, cancelled stale query, no results, outside-area, quota, offline, token renewed after selection.
- **ImageProcessingTests**: large noisy image ≤ 800_000 bytes; small image untouched dimensions; quality loop lowers quality then dimension; no GPS/EXIF; corrupt data throws.
- **ListingServiceCreateTests**: request body equals contract JSON (snake_case, disabled day has only `enabled`, no `description` when empty, `hourly_rate_cents` int); 201 fixture decodes with `address == nil`; error mapping.
- **PhotoUploaderTests**, **ListingDraftStoreTests** (round-trip, corrupt file, clear).

### Integration / UI
XCUITest (later, plan 14): fake service via launch argument, walk the wizard end to end.

### Edge Cases
App killed mid-wizard (draft restore incl. photos); address outside 11372 after selection; user edits address text after selecting (selection cleared); schedule with only Sunday; picker returns HEIC, panorama, 40 MP; user removes photo while another is processing; device time zone ≠ New York (times unchanged); backgrounding during upload (use `beginBackgroundTask` around the create request; resume otherwise); 401 during publish (sign-out flow, draft is wiped by sign-out — accept, note); duplicate submit; Airplane mode mid-publish; Places quota exceeded (manual typed-address fallback is intentionally **not** offered: coordinates are required).

## VALIDATION COMMANDS (from `iOS/`)
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/ListingValidatorsTests -only-testing:SpotiqueTests/ListingWizardViewModelTests -only-testing:SpotiqueTests/AddressAutocompleteViewModelTests -only-testing:SpotiqueTests/ImageProcessingTests -only-testing:SpotiqueTests/ListingServiceCreateTests`
### Level 3: Full suite
Same command without `-only-testing`.
### Level 4: Manual
Device run with a real Places key: type "74th St", pick a 11372 result, pick one outside (11373/11368) → blocked; select geotagged photos, inspect uploaded bytes for EXIF; kill app at step 5 and relaunch; airplane-mode publish; VoiceOver + XXL Dynamic Type walk-through; confirm pin shows on the map < 30 s.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Photo upload format: base64 data URI, raw base64, or presigned URL (`/uploads`)? Body size limit for base64 (≤ ~4.3 MB)? | README gap 6; contract `<upload_url_or_base64>` | Pending; default `Base64PhotoUploader` with data-URI |
| 2 | How does the duplicate-address warning arrive (`meta.warnings`? field on 201)? Not defined in contract. | Contract `POST /listings` | Pending; assume `meta.warnings: ["duplicate_address"]` |
| 3 | Multiple listings per host allowed? | PRD §8 Q4 | Assume allowed |
| 4 | Payment text max length and whether required; PRD "required fields" includes it. | PRD §4.2 | Assume required, ≤ 60 |
| 5 | Exact 11372 boundary polygon vs bounding rectangle; does API validate zip from `address` string? | Contract | Rectangle + post-check + server check |
| 6 | Overnight windows and "24:00" end — supported? | Contract | Assume no; end ≤ 23:45 |
| 7 | Should exact coordinates be returned to drivers pre-confirmation (privacy)? | PRD §7.2 vs contract | Recommend server-side jitter |
| 8 | Is `POST /listings` idempotent / does it accept an Idempotency-Key? | Discovered | Pending |
| 9 | Contract still says "Firestore" in listing text; confirm REST-only. | README gap 1/10 | Pending |
| 10 | Places key provisioning per environment (Debug/Release) and billing owner. | Discovered | Pending |

## ACCEPTANCE CRITERIA
- [ ] Address field uses Places Autocomplete restricted to 11372; coordinates + formatted address extracted; outside-11372 selections are rejected with clear copy
- [ ] 1–4 photos enforced; every uploaded image ≤ 800 KB, JPEG, no EXIF/GPS (tested)
- [ ] Rate whole dollars $5–$50 → 500–5000 cents; description ≤ 200; schedule needs ≥ 1 enabled day with end > start
- [ ] Wizard order matches PRD §6.1; per-step validation, back/next, and Preview with street-name-only address
- [ ] Listing is active on creation; map/Listings tab refetch immediately (pin visible < 30 s, server permitting)
- [ ] Duplicate-address warning shown but never blocks
- [ ] Draft survives backgrounding and app kill; cleared on publish/sign-out
- [ ] Partial upload failure retries only failed photos; offline/quota/no-results states handled
- [ ] VoiceOver labels, 44pt targets, Dynamic Type, keyboard types/focus, localization complete
- [ ] All validation commands pass; no regressions; privacy model upheld; `docs/api-contract.md` updated for warnings/uploads decisions

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Places API key restricted (bundle ID + Places API) and not committed
- [ ] Open questions 1, 2, 4 answered or assumptions recorded in code comments

## NOTES
- Chose ImageIO over `UIImage.jpegData` because it downsamples without decoding full bitmaps and guarantees metadata-free output.
- Chose base64 default because it is the only path the current contract can express without a new endpoint; the protocol makes the swap one line.
- `ListingFormModel` is intentionally separate from the wizard so plan 08's edit screen reuses steps and validators verbatim.
- Project default MainActor isolation: `ListingValidators`, `ImageProcessing`, request models are `nonisolated`; views/VMs stay MainActor.
- The wizard never derives a display address from coordinates; the preview string uses Places' `route` component and is labeled best-effort — the server's `display_address` wins after publish.
