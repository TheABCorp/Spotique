# Feature: Hardening & Release Readiness (Accessibility, Offline, Performance, Security/Privacy, Localization, CI/CD)

> Validate documentation, codebase patterns, and task sanity before implementing. This is the final pass over plans 01–13: it owns no new product features, only cross-cutting verification, small shared components (offline banner, reachability, privacy shield), configuration (privacy manifest, entitlements, Info.plist keys, Xcode Cloud) and release checklists. Where a finding belongs to an earlier plan, this plan names it — fix in that plan's files.

**Source:** `docs/prd-v1.md` §7.1–§7.4 (performance, security & privacy, accessibility, offline), §5 (Spanish post-launch), §8; `iOS/plans/README.md`; `.claude/skills/{xcode-cloud,ios-performance,ios-security-review,swift-code-review}`.

## Feature Description

Bring the app to App Store/TestFlight quality: automated accessibility audits and a per-screen checklist; offline behavior (reachability service, offline banner, cache policy); measured performance budgets; a security/privacy review with a privacy manifest and App Store privacy label inputs; String Catalog completeness; Xcode Cloud workflows; and a release checklist.

## User Story

As a Spotique user (host or driver, including those using assistive tech or poor connectivity) / I want an app that is accessible, fast, works sensibly offline and protects my address and phone number / So that I can trust and use it in Jackson Heights every day; and as the team, ship it confidently.

## Problem Statement

Each feature plan states accessibility, offline and privacy constraints locally, but nothing verifies them together. There is no reachability service, offline banner, privacy manifest, performance baseline, CI, or release configuration; several PRD non-functional requirements (§7) are only satisfied if screens across plans cooperate.

## Solution Statement

Add a small set of shared pieces and a repeatable audit: `NetworkMonitor` + `OfflineBanner`, `PrivacyShield` (app-switcher), signposts and XCTest metrics, `PrivacyInfo.xcprivacy`, generated `Info.plist` keys and entitlements, `ci_scripts` and Xcode Cloud workflow spec; then run per-screen checklists and record results in the PR. Findings are routed back to the owning plan.

## Requirements & Acceptance Criteria

Verbatim PRD §7:
- 7.1: "Map loads within 3 seconds on LTE connection (iPhone 12 / Pixel 5 or newer)"; "App cold launch within 3 seconds on supported minimum device"; "Booking request submission completes within 2 seconds"; "Push notifications delivered within 5 seconds of Firestore trigger" (server).
- 7.2: "Verified phone number or email address required for all access"; "Full listing address hidden in map view and spot detail; revealed only after booking confirmation"; "Host phone number revealed only to confirmed drivers; driver phone revealed only to host after booking creation"; "No third-party analytics SDK that shares user data during MVP"; "Google Maps and Places API keys restricted to app bundle IDs" (Firestore rules line is server/stale — README gap 1).
- 7.3: "VoiceOver … support for all interactive elements"; "Minimum 44×44pt touch targets on all tappable elements"; "Color contrast ratio ≥4.5:1 for all body text; ≥3:1 for large text and UI components"; "No information conveyed by color alone (always paired with icon or text label)".
- 7.4: "Previously loaded map data and user's own listings and bookings are shown from cache when offline"; "Booking submission requires active connection; a clear offline error is shown"; "Photos cached locally for recently viewed spots".
- §5: Spanish localization is post-launch — this plan ensures **extraction only**.

## Feature Metadata

**Feature Type**: Enhancement (cross-cutting) / Release
**Estimated Complexity**: High (breadth, not depth)
**Platforms**: iOS (+ manual App Store Connect / Apple Developer steps)
**Primary Systems Affected**: all of `iOS/Spotique/`, `iOS/SpotiqueUITests/`, project settings, `iOS/ci_scripts/`
**Dependencies**: Google Maps SDK + Places SDK (plans 03/07) manifests, Xcode Cloud, App Store Connect

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `iOS/Spotique.xcodeproj/project.pbxproj` — `GENERATE_INFOPLIST_FILE = YES` (Info.plist keys go in build settings as `INFOPLIST_KEY_*`), `TARGETED_DEVICE_FAMILY = "1,2"`, portrait+landscape orientations, `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`, `INFOPLIST_KEY_UILaunchScreen_Generation = YES`, `STRING_CATALOG_GENERATE_SYMBOLS`, `SWIFT_EMIT_LOC_STRINGS`. No `CODE_SIGN_ENTITLEMENTS` yet.
- `iOS/plans/01-foundation.md` — components, `APIClient`/`APIError.offline`, `TokenStore`, `Log`, `ModelContainerFactory`, `AppEnvironment`, fixtures, UI-test launch approach.
- Plans 03 (map cache), 04 (image cache/gallery), 05 (submit), 06/10 (bookings cache), 07/08 (listing mutations), 09 (inbox), 11 (push, entitlements), 12 (ratings), 13 (settings, delete account) — screen inventory below.
- `.claude/skills/xcode-cloud/SKILL.md`, `ios-performance`, `ios-security-review`, `swift-code-review`, `spotique-brand-ui`.

### New Files to Create
```
iOS/Spotique/Core/Networking/NetworkMonitor.swift            ReachabilityProviding protocol + NWPathMonitor-backed @Observable
iOS/Spotique/Core/DesignSystem/Components/OfflineBanner.swift
iOS/Spotique/Core/Security/PrivacyShield.swift               scenePhase overlay for app-switcher snapshots
iOS/Spotique/Core/Logging/Signposts.swift                    OSSignposter intervals (map first pins, launch to interactive, booking submit)
iOS/Spotique/PrivacyInfo.xcprivacy
iOS/Spotique/Spotique.entitlements                           (created by plan 11; verify here)
iOS/Config/{Debug,Release}.xcconfig, Secrets.example.xcconfig   (Secrets.xcconfig gitignored)
iOS/ci_scripts/{ci_post_clone,ci_pre_xcodebuild,ci_post_xcodebuild}.sh
iOS/TESTFLIGHT_NOTES.md                                      "What to Test" source (release notes file used by workflow)
iOS/SpotiqueUITests/{AccessibilityAuditTests,DynamicTypeTests,OfflineUITests,LaunchPerformanceTests}.swift
iOS/SpotiqueTests/{NetworkMonitorTests,OfflineBehaviorTests,PrivacyRegressionTests,LocalizationCatalogTests}.swift
iOS/SpotiqueTests/Fakes/FakeNetworkMonitor.swift
```

### Documentation — READ BEFORE IMPLEMENTING
- [Performing accessibility audits (XCUITest)](https://developer.apple.com/documentation/xctest/xcuiapplication/performaccessibilityaudit(for:_:)) — `performAccessibilityAudit(for:)` (Xcode 15+).
- [Accessibility for SwiftUI](https://developer.apple.com/documentation/swiftui/accessibility) and [Evaluating for contrast](https://developer.apple.com/documentation/accessibility/accessibility-nutrition-labels) / HIG Accessibility.
- [NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor).
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) and [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/); [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) §1.2 (UGC), §5.1.1(v) (account deletion), §4.
- [Xcode Cloud workflows](https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution) and [Writing custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts).
- [Google Maps iOS SDK privacy manifest notes](https://developers.google.com/maps/documentation/ios-sdk/) (verify SDK versions ship `PrivacyInfo.xcprivacy`).
- `docs/api-contract.md` § Error Format (`offline` is client-side only).

### Skills to Apply
`ios-performance` (method: measure, change one thing), `ios-security-review` (checklist below), `swift-code-review`, `swiftui-development`, `spotique-brand-ui`, `xcode-cloud`, `swift-concurrency-6-2`.

### Patterns to Follow
Unit tests in Swift Testing; UI audits in XCTest. `AppEnvironment.preview` supplies fakes; a `-uiTesting` launch argument (plan 01/02) selects a stubbed environment so UI tests are hermetic. Logging via `Log.*` with `.private`.

---

## PRIVACY & SECURITY

This plan verifies, across **all screens, caches, logs, snapshots, notifications**, that the full street address and host phone are absent before `confirmed` and that driver phone is only visible to the host. Server enforcement is assumed (contract: `address`/phones only on confirmed bookings, redacted otherwise) — the audit confirms the client never derives/holds/persists them earlier and that leaving `confirmed` (cancel/decline) purges cached copies. Sensitive fields legitimately held after confirmation (address, host phone, payment text) are cached only for the user's own confirmed bookings, excluded from backup, and wiped on sign-out/account delete.

## IMPLEMENTATION PLAN

### Phase 1: Foundation — `NetworkMonitor`, `OfflineBanner`, `PrivacyShield`, signposts, config files, manifest
### Phase 2: Core — audits, adoption edits routed to owning plans, XCTest metrics/UI audits, localization check
### Phase 3: Integration — CI workflows, entitlements/Info.plist, release assets
### Phase 4: Testing & validation — full matrix on device, Instruments runs, TestFlight dry run

### A. Accessibility audit checklist (per screen; run on every screen of plans 02–13)
For each screen record pass/fail: (1) VoiceOver: every interactive element has label/value/hint/trait; reading order matches visual; decorative images hidden; custom controls expose actions (`accessibilityAction`) — e.g. map pins are reachable via a list alternative; (2) Dynamic Type from `xSmall` to `accessibilityXXXL`: no truncation of critical info (price, status, time), layouts reflow (`ViewThatFits`/`@ScaledMetric`), no clipped buttons; (3) contrast: body >= 4.5:1, large text and UI >= 3:1 in light and dark; (4) 44x44pt targets incl. icon buttons, chips, stepper controls, map controls; (5) no color-only info (status badges, selected tags/thumbs, availability greyed days, validation errors); (6) Reduce Motion (`accessibilityReduceMotion`): no parallax/spring-heavy transitions, gallery paging, map camera animations shortened; Reduce Transparency/Increase Contrast for Liquid Glass surfaces; (7) focus/announcements after async results (errors, success), sheets return focus.

| Plan | Screens to audit |
|------|------------------|
| 02 | phone/email entry, code entry (`.oneTimeCode`), complete profile, role select |
| 03 | map, pin preview card, "When" filter sheet, type filter, list alternative |
| 04 | gallery, detail, availability, redacted address block |
| 05 | time selection, total, conflict/offline errors, submit |
| 06/10 | My Bookings, filter tabs, booking detail, countdown, confirmed reveal |
| 07/08 | wizard steps, autocomplete list, photo picker, schedule editor, toggle/edit/delete |
| 09 | inbox, accept/decline sheet |
| 11/12/13 | priming sheet, preferences, rating sheet, no-show prompt, profile, settings, delete-account confirmation |

**Known risk (flag to plan 01 / brand skill):** Brand Gold `#C5943C` on Ivory `#F7F3EC` is roughly 2.5:1 (verify with a contrast tool) — fails both 4.5:1 and 3:1. Gold must be fills/decoration only, with Navy text on Gold (approx 6:1). Audit every gold usage (badges, prices, links, icons on ivory) and confirm dark-mode variants.

### B. Offline behavior matrix (PRD §7.4)
| Surface | Offline behavior | Owner to adopt |
|---------|-----------------|----------------|
| Map / listing pins | Show last loaded pins from `CachedListing` (SwiftData, redacted fields only) with "Showing saved results" caption; disable "When" server search | 03 |
| Spot detail | Cached listing + cached photos (below); "Request booking" disabled with "Connect to the internet to request a booking" | 04, 05 |
| Request booking submit | Blocked; `APIError.offline` -> clear message; never queue | 05 |
| My Bookings / history | Show `CachedBooking` snapshot with "Last updated" caption; confirmed address/host phone visible if cached (post-confirmation only) | 06, 10 |
| Host inbox | Cached pending list, read-only; accept/decline disabled offline | 09 |
| Host listings | Cached own listings viewable; create/edit/toggle/delete require connection | 07, 08 |
| Ratings / no-show / preferences / profile edits | Require connection; explicit error; no queue | 11, 12, 13 |
| Auth | Requires connection; cached session shell opens signed-in | 01, 02 |
| Photos | `URLCache`-backed image cache (e.g. 50 MB memory / 300 MB disk) with LRU for recently viewed spots; downsampled to display size | 04 (plan 01 lists an image cache but defines no task — **create `Core/Storage/ImageCache.swift` here if plan 04 hasn't**) |

Shared pieces: `ReachabilityProviding { var isOnline: Bool; var updates: AsyncStream<Bool> }`, `NetworkMonitor` (NWPathMonitor on a private queue; `path.status == .satisfied`; also treat `.constrained` as online), `OfflineBanner` (icon + text "You're offline. Showing saved data.", `role: status`, announced once via `AccessibilityNotification.Announcement`), placed by `MainTabView` (plan 01/06) as a safe-area inset. Reachability is advisory: always let requests run and map failures via `APIError.offline` (NWPathMonitor can lie on captive portals). On reconnect trigger refresh via the same stream.

### C. Performance budgets and measurement (use `ios-performance`)
| Metric (PRD §7.1) | Budget | How measured |
|-------------------|--------|--------------|
| Cold launch to first interactive frame | <= 3.0 s on oldest supported device (PRD names iPhone 12/Pixel 5; iOS 26.1 also runs on iPhone 11 — test the oldest available) | Instruments App Launch (Release, device); `XCTApplicationLaunchMetric` in `LaunchPerformanceTests`; signpost `launch` |
| Map with pins loaded | <= 3 s on LTE (Network Link Conditioner "LTE" profile, real device) | `OSSignposter` interval `map.firstPins` from `MapViewModel.onAppear` to first annotations rendered; Instruments Network + Time Profiler |
| Booking submit | <= 2 s (client-observed round trip on LTE) | Signpost `booking.submit` around `submit()`; XCTest `measure` against local API/stub with latency injection; server p95 tracked separately |
| Scrolling / map pan | 60 fps, no hangs | Animation Hitches + Hangs; clustering (plan 03) |
| Memory | No growth on repeated push/pop of detail | Allocations/Leaks, Memory Graph |
| Push latency <= 5 s | server metric | manual timestamps |
Rules: measure a Release build on a device; change one thing at a time; record baseline/after in the PR. Launch: no SDK init or network before first frame (Google Maps SDK key set lazily in plan 03); `ModelContainer` lazy. Avoid MetricKit/analytics upload (no third-party; local `os_signpost` only).

### D. Security & privacy review checklist (`ios-security-review`)
Run the skill against `iOS/` and record High/Medium/Low. Required checks, each with a command or test:
- Keychain only for token, `AfterFirstUnlockThisDeviceOnly`: `grep -rn "UserDefaults" Spotique/` and review each hit (allowed: priming counters, rated-booking IDs, preference cache; forbidden: token, phone, address, notes).
- ATS untouched: `grep -rn "NSAllowsArbitraryLoads\|NSExceptionDomains" Spotique.xcodeproj Spotique` -> none in Release; Debug `localhost` exception scoped via xcconfig.
- No `print(`, no tokens/phones/addresses/notes in logs: `grep -rn "print(\|dump(\|NSLog(" Spotique/`; verify `Logger` calls use `.private`; a `PrivacyRegressionTests` test scans app source strings for `Log.` calls that interpolate `address`, `phone`, `token`, `note`.
- Privacy across ALL surfaces (tests + manual): for each of map pin/preview, spot detail, request booking, pending/declined/cancelled booking detail, host inbox, history, notifications payloads (plan 11), SwiftData caches, image cache, `UserDefaults`, crash logs, pasteboard, screenshots: assert `address == nil`, `hostPhone == nil` while status != confirmed (fixtures `booking-pending.json`, `booking-declined.json`), and that cache rows for a booking are purged when status leaves confirmed or on sign-out (`OfflineBehaviorTests`). `driverPhone` appears only in host contexts.
- App-switcher snapshot: `PrivacyShield` overlays brand-neutral blur/logo when `scenePhase != .active` (at minimum on booking detail with revealed address/phone; simplest is app-wide); `.privacySensitive()` on address/phone views; verify by backgrounding on the confirmed booking screen and viewing the app switcher.
- Pasteboard: no automatic copying; phone number actions use `tel:` link, address uses Apple Maps handoff (no `LSApplicationQueriesSchemes` needed unless `canOpenURL`).
- Deep links/push untrusted (plan 11); auth required before acting.
- No analytics SDK: audit Package.resolved/SPM: only Google Maps + Places (and their transitive deps); no Firebase Analytics/Crashlytics.
- Google keys restricted to bundle ID `com.actionman.Spotique` (Cloud Console) and API scopes; keys via xcconfig, not in source.
- Data at rest: SwiftData store/image cache excluded from backup (`isExcludedFromBackup`), file protection `.completeUntilFirstUserAuthentication` (or stricter for confirmed data).
- Sign-out and account delete wipe Keychain, in-memory user, SwiftData, image cache, UserDefaults keys, delivered notifications and badge (test in `OfflineBehaviorTests`/`SessionStoreTests`).
- Jailbreak/screenshot detection: out of scope.

### E. PrivacyInfo.xcprivacy
Create `iOS/Spotique/PrivacyInfo.xcprivacy` (app target membership):
- `NSPrivacyTracking` = false; `NSPrivacyTrackingDomains` = []. (No IDFA, no ATT prompt.)
- `NSPrivacyCollectedDataTypes` (all: Linked to user = true; Tracking = false; Purpose = App Functionality, and Account Management/Customer support where noted): `PhoneNumber`, `EmailAddress`, `Name`, `PhysicalAddress` (home address and listing address), `PhotosorVideos` (listing photos), `UserID`, `OtherUserContent` (listing description, private rating notes, payment method text), `DeviceID` (APNs device token — confirm classification), `CoarseLocation`/`PreciseLocation` **only if** plan 03 adds a "my location" button (recommend no in MVP; then no location purpose string). Ratings/no-show history: declare as `OtherUserContent`; booking records as `PurchaseHistory` is debatable (no on-platform payment) — decision in Open Questions.
- `NSPrivacyAccessedAPITypes` (declare only APIs the code actually uses; verify with `grep` and Xcode's privacy report): `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` (app's own defaults); `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1` **if** image-cache/eviction reads file dates inside the app container; `NSPrivacyAccessedAPICategoryDiskSpace` `E174.1` only if free-space checks exist; `NSPrivacyAccessedAPICategorySystemBootTime` `35F9.1` only if `ProcessInfo.systemUptime`/`mach_absolute_time` is used for elapsed time (signposts/`ContinuousClock` generally are not). **Keychain is not a required-reason API** — no entry needed. Missing/unnecessary declarations are both review risks.
- Third-party SDK manifests: Google Maps iOS SDK and Google Places SDK ship their own manifests in recent versions — pin to versions that include `PrivacyInfo.xcprivacy` and signature (verify via Archive -> "Generate Privacy Report" which aggregates SDK manifests). If Firebase were retained (README gap 1), its manifests are required too.
- App Store privacy "nutrition label" inputs (App Store Connect): Contact Info (Name, Email, Phone, Physical Address) — linked, not tracking, App Functionality; User Content (Photos, Other User Content) — linked, App Functionality; Identifiers (User ID, Device ID for push) — linked, App Functionality; Location only if added; Usage/Diagnostics: none (no analytics); Data used for tracking: none. Privacy policy URL required; must state address/phone sharing rules.

### F. Localization completeness
`Localizable.xcstrings` (plan 01) must contain every user-facing string of plans 01–13. English only for launch; Spanish is post-launch, so the goal is **extraction and translation-readiness**. Checks: no hard-coded literals outside `Text/Label/Button` with `LocalizedStringKey` (non-View strings use `String(localized:)`/`LocalizedStringResource`); `APIError.errorDescription`, push copy, tag labels, formatter output localized; pluralization variations for counts (bookings, no-shows, hours); dates/currency via `FormatStyle` (no manual formats); no string concatenation for sentences; String Catalog has no `stale` or `new` entries; notifications localized server-side using `Accept-Language`. Test with pseudolanguages (double-length, accented, right-to-left) via scheme options; run `-NSDoubleLocalizedStrings YES` in UI tests.

### G. Xcode Cloud workflow specification (per `xcode-cloud`)
| Workflow | Start condition | Actions | Notes |
|----------|-----------------|---------|-------|
| PR Checks | PR to `main`, changes under `iOS/` | Build + Test (scheme `Spotique`, iPhone 16 simulator, unit tests) | Environment: `API_BASE_URL`, `GOOGLE_MAPS_API_KEY` (dev) as secrets |
| Main CI | Push to `main`, changes under `iOS/` | Build, unit + UI tests (`SpotiqueUITests` with `-uiTesting`), coverage on | Post-action: notify |
| TestFlight Beta | Push to `main` (iOS changes) or tag `ios-v*` | Test, Archive iOS, TestFlight Internal Testing group | "What to Test" from `iOS/TESTFLIGHT_NOTES.md` |
| Release | Tag `ios-release-*`, manual approval | Archive, External TestFlight / submit | Manual until MVP shipped |
`ci_scripts` (executable, `set -euo pipefail`, no echo of secrets): `ci_post_clone.sh` writes `iOS/Config/Secrets.xcconfig` from `GOOGLE_MAPS_API_KEY`, `GOOGLE_PLACES_API_KEY`, `API_BASE_URL` env secrets and resolves SPM packages (commit `Package.resolved`); `ci_pre_xcodebuild.sh` sets `CURRENT_PROJECT_VERSION=$CI_BUILD_NUMBER`; `ci_post_xcodebuild.sh` optional summary. Info.plist keys reference `$(GOOGLE_MAPS_API_KEY)` via `INFOPLIST_KEY_`/user-defined settings. Use separate dev/prod keys and API URLs. Pin Xcode to the iOS 26.1-capable version. Hermetic tests only (no live API/SMS).
**Manual steps** (cannot be automated in repo): create App ID `com.actionman.Spotique` with Push Notifications capability; create App Store Connect app record; connect repo and grant Xcode Cloud access; create workflows and env secrets; create internal TestFlight group; upload APNs auth key (.p8) to the Rails server config (production + sandbox); fill App Privacy, age rating, export compliance, support/privacy-policy URLs, screenshots, review notes and a **demo login path** (SMS/email OTP cannot be received by App Review — needs a fixed demo account/code on the server); enable Google API key restrictions.

### H. Release-readiness checklist
- App icon: 1024 px `AppIcon` (Icon Composer light/dark/tinted for iOS 26), no transparency; Brand Navy/Gold.
- Launch screen: generated (`INFOPLIST_KEY_UILaunchScreen_Generation = YES`); set `UILaunchScreen` background to `BrandIvory` + logo image; no text.
- Version/build: `MARKETING_VERSION = 1.0.0`; build number from `CI_BUILD_NUMBER`; tags `ios-v*`.
- Device family/orientation: currently `TARGETED_DEVICE_FAMILY = "1,2"` with landscape enabled — MVP is phone-first; recommend iPhone only (`1`) and portrait only, or audit iPad/landscape layouts (open question).
- Entitlements: `aps-environment` (plan 11) via `CODE_SIGN_ENTITLEMENTS`; no Background Modes (no silent push), no Associated Domains.
- Info.plist keys (via `INFOPLIST_KEY_*`): `ITSAppUsesNonExemptEncryption = NO` (HTTPS only, no custom crypto) ; `NSLocationWhenInUseUsageDescription` only if plan 03 adds device location (recommend omit); `NSCameraUsageDescription` only if plan 07 adds camera capture; `PhotosPicker` (SwiftUI) needs **no** photo library usage string because it runs out-of-process and grants only selected assets — a string is needed only if `PHPhotoLibrary` direct access is used; `GMSApiKey`/Places key from xcconfig; ATS default; `UIApplicationSceneManifest`; supported languages `en`.
- App Review: UGC (listing photos/descriptions) triggers Guideline 1.2 — need report/block mechanism and moderation contact (no such feature in plans 01–13: raise as blocker); account deletion in-app (plan 13, Guideline 5.1.1(v)); demo account; privacy policy.
- Crash-free: run Thread/Address Sanitizer and Main Thread Checker passes; no warnings.

---

## STEP-BY-STEP TASKS

Run from `iOS/`. Base test command: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### CREATE Core/Networking/NetworkMonitor.swift, Fakes/FakeNetworkMonitor.swift
- **IMPLEMENT**: `protocol ReachabilityProviding` + `@Observable @MainActor final class NetworkMonitor` wrapping `NWPathMonitor` (start on init, cancel on deinit, publish `isOnline` and an `AsyncStream<Bool>`). Add to `AppEnvironment` (`.live` and `.preview`).
- **PATTERN**: protocol-DI per `mvvm-architecture`; `nonisolated` handler hopping to MainActor (default isolation gotcha, plan 01 NOTES).
- **GOTCHA**: initial path update arrives async; treat unknown as online. Don't gate requests on it.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/NetworkMonitorTests` (online->offline->online transitions via fake).

### CREATE Core/DesignSystem/Components/OfflineBanner.swift and adopt in plans 03/04/05/06/09/10
- **IMPLEMENT**: banner + `.offlineAware()` view modifier reading `NetworkMonitor`; adopt in `MainTabView` as a top safe-area inset; per-screen disabled-state copy for mutation buttons. Adoption edits are made in the owning plans' files (03, 05, 06, 09, 10; 07/08/12/13 mutations).
- **GOTCHA**: never rely on color alone (icon + text); announce once, not on every render; reduce motion.
- **VALIDATE**: `... test -only-testing:SpotiqueUITests/OfflineUITests` (stub monitor offline: banner visible, submit disabled with message, cached bookings visible).

### CREATE/VERIFY Core/Storage caches and ImageCache
- **IMPLEMENT**: confirm plans 03/06 register `CachedListing`/`CachedBooking` in `ModelContainerFactory`; confirm no `address`/`hostPhone` columns exist on `CachedListing` and that `CachedBooking` stores them only when `status == .confirmed`, purged on status change/sign-out. Create `ImageCache` (URLCache-based disk cache with size limit and file protection) if plan 04 did not.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/OfflineBehaviorTests` (offline read of cached listings/bookings; purge on decline; sign-out wipes; no address on non-confirmed rows).

### CREATE Core/Security/PrivacyShield.swift and UPDATE App/RootView.swift
- **IMPLEMENT**: overlay view (brand background + logo) shown when `scenePhase != .active`; apply at the root.
- **GOTCHA**: `.inactive` also occurs for system alerts/Control Center; keep the overlay non-interactive and instant. Provide `.privacySensitive()` extension for address/phone views.
- **VALIDATE**: manual app-switcher check; UI test asserting shield identifier present after `XCUIDevice.shared.press(.home)` + return.

### CREATE Core/Logging/Signposts.swift and instrument
- **IMPLEMENT**: `enum Signpost { static let launch, mapFirstPins, bookingSubmit }` using `OSSignposter`; add intervals in `SpotiqueApp`, `MapViewModel`, `RequestBookingViewModel` (edits in plans 01/03/05 files).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; view in Instruments Points of Interest.

### CREATE SpotiqueUITests/AccessibilityAuditTests.swift, DynamicTypeTests.swift
- **IMPLEMENT**: with `-uiTesting` stubbed environment, navigate each screen in the table and call `try app.performAccessibilityAudit(for: [.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .dynamicType, .textClipped, .trait])`. Use the issue handler only for documented, ticketed exceptions (e.g. map canvas). A second run launches with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` and asserts key elements (`price`, `status badge`, primary CTA) are hittable and not clipped; a third with dark appearance (`-AppleInterfaceStyle Dark`).
- **GOTCHA**: audits find element-level issues, not reading-order/semantic problems — still do the manual VoiceOver pass from checklist A. Reduce Motion is verified manually (Accessibility Inspector / Settings) and via a unit test that `withAnimation` helpers respect `accessibilityReduceMotion`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueUITests/AccessibilityAuditTests`

### CREATE SpotiqueUITests/LaunchPerformanceTests.swift and performance runs
- **IMPLEMENT**: `measure(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric()])` for launch (signed-in cached shell and signed-out); measure booking submit against stubbed latency. Record device baselines in the PR; run Instruments (App Launch, Time Profiler, Hangs, Animation Hitches, Network) per plan C.
- **VALIDATE**: `... test -only-testing:SpotiqueUITests/LaunchPerformanceTests` (simulator numbers are indicative only; device numbers gate release).

### CREATE PrivacyInfo.xcprivacy, project settings, Config/*.xcconfig
- **IMPLEMENT**: manifest per section E; verify required-reason usage with `grep -rnE "UserDefaults|creationDate|modificationDate|contentModificationDateKey|systemUptime|mach_absolute_time|volumeAvailableCapacity" Spotique/`; wire `Secrets.xcconfig` (gitignored) + `Secrets.example.xcconfig`; `.gitignore` entries; Info.plist keys per checklist H; `CODE_SIGN_ENTITLEMENTS` (from plan 11).
- **GOTCHA**: Google SDK keys must not appear in git; Release must not fall back to the debug base URL.
- **VALIDATE**: `plutil -lint Spotique/PrivacyInfo.xcprivacy && xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; on archive: Xcode Organizer -> Generate Privacy Report and compare with declared types.

### CREATE SpotiqueTests/LocalizationCatalogTests.swift and run localization audit
- **IMPLEMENT**: test parses `Localizable.xcstrings` (JSON) and fails on `"extractionState": "stale"`, empty `en` values, or missing plural variations for keys flagged; documented list of allowed exceptions. Also `xcodebuild -exportLocalizations` to confirm extraction.
- **VALIDATE**: `xcodebuild -exportLocalizations -project Spotique.xcodeproj -localizationPath /tmp/spotique-loc -exportLanguage en` then `... test -only-testing:SpotiqueTests/LocalizationCatalogTests`.

### CREATE SpotiqueTests/PrivacyRegressionTests.swift
- **IMPLEMENT**: decode `booking-pending/declined/cancelled` fixtures -> address/phones nil; view-model level tests that no ViewModel exposes address/phone before confirmed; notification payload fixtures (`SpotiqueTests/Fixtures/push/*.apns`) contain no `address`/`phone` keys or digits patterns.
- **VALIDATE**: `... test -only-testing:SpotiqueTests/PrivacyRegressionTests`

### CREATE ci_scripts/*, Xcode Cloud workflows (manual), TESTFLIGHT_NOTES.md
- **IMPLEMENT**: scripts per section G, `chmod +x`; `TESTFLIGHT_NOTES.md` with "What to Test". Configure the four workflows in Xcode (Product > Xcode Cloud) with iOS file filters and secret env vars.
- **GOTCHA**: scripts run from repo root context `CI_PRIMARY_REPOSITORY_PATH`; use it to reach `iOS/Config`. Never `echo` secrets.
- **VALIDATE**: `bash -n ci_scripts/ci_post_clone.sh && test -x ci_scripts/ci_post_clone.sh`; dry-run locally with dummy env vars; first PR triggers PR Checks.

### RUN review passes and record findings
- **IMPLEMENT**: run `ios-security-review` (Section D), `swift-code-review` on the full app, `ios-performance` (Section C), VoiceOver/Dynamic Type/contrast manual passes (Section A). File each finding against its owning plan number.
- **VALIDATE**: findings table added to the PR; all High resolved.

---

## TESTING STRATEGY

### Unit Tests
`NetworkMonitorTests`, `OfflineBehaviorTests`, `PrivacyRegressionTests`, `LocalizationCatalogTests`; existing suites must stay green.

### Integration / UI Tests
`AccessibilityAuditTests`, `DynamicTypeTests`, `OfflineUITests`, `LaunchPerformanceTests` with stubbed environment; hermetic (no network).

### Edge Cases
Airplane mode mid-request; captive portal; cellular constrained/Low Data Mode; switching offline/online while a submit is in flight; cached data older than X days; sign-out while offline (wipe still succeeds); low disk; VoiceOver + Dynamic Type combined; dark mode + Increase Contrast; Reduce Motion; iPhone SE-size layout; first launch after fresh install; upgrade with existing Keychain token (Keychain survives reinstall — decide whether to require re-login on fresh install, security note).

## VALIDATION COMMANDS
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build` and `plutil -lint Spotique/PrivacyInfo.xcprivacy`; greps from Section D.
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests`
### Level 3: Integration Tests
`... test -only-testing:SpotiqueUITests` (accessibility audits, Dynamic Type, offline, launch); generic device archive check: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -destination generic/platform=iOS archive -archivePath /tmp/Spotique.xcarchive CODE_SIGNING_ALLOWED=NO`.
### Level 4: Manual Validation
Real-device Instruments runs (launch, map on LTE profile, submit); VoiceOver walkthrough of the driver flow (6.2) and host flow (6.1); app-switcher shield check; Airplane-mode matrix; TestFlight internal build installed and smoke-tested; Privacy Report review.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Minimum device: PRD says iPhone 12; deployment target iOS 26.1 supports iPhone 11+. Which device is the launch/perf gate? | PRD §7.1 | Pending |
| 2 | Brand Gold on Ivory fails contrast — allowed uses? | Brand skill / §7.3 | Gold as fill only, Navy text |
| 3 | UGC moderation (report/block) required by App Review 1.2 — no plan covers it | App Review | Blocker to raise |
| 4 | Demo account/OTP bypass for App Review | Discovered | Needs server support |
| 5 | Does the app request device location (`NSLocationWhenInUse…`)? | PRD §4.4 vs §7.2 minimal data | Recommend no |
| 6 | Privacy label classification: APNs token (Device ID), booking records (Purchase History?) | App privacy details | Pending review |
| 7 | iPad and landscape support (currently enabled by template) | Project settings | Recommend iPhone-portrait for MVP |
| 8 | Cache retention (age limits) for offline bookings/photos | PRD §7.4 | Proposed 30 days/300 MB |
| 9 | Keychain token survives app reinstall — clear on first launch? | ios-security-review | Pending |
| 10 | REST/JWT vs Firebase (privacy manifests, `GoogleService-Info.plist` in CI) | README gap 1 | Assumed REST only |
| 11 | Push latency ≤ 5 s and contract "Firestore trigger" wording | PRD §7.1 | Server concern |

## ACCEPTANCE CRITERIA
- [ ] Accessibility audit passes on every screen; VoiceOver, Dynamic Type XXXL, contrast, 44pt, no color-only, Reduce Motion verified
- [ ] Offline matrix implemented: cached map/listings/bookings/photos; submission blocked with clear offline error; banner shown
- [ ] Performance budgets measured on device: launch <= 3 s, map <= 3 s (LTE), submit <= 2 s
- [ ] Security/privacy review has no unresolved High; no address/host phone before confirmation anywhere; snapshot hidden; no analytics SDK
- [ ] `PrivacyInfo.xcprivacy` accurate; privacy report matches App Store label inputs
- [ ] String Catalog complete, no stale entries, English only extracted
- [ ] Xcode Cloud workflows (PR, main, TestFlight) run green; internal TestFlight build installs
- [ ] Release checklist complete (icon, launch screen, versions, entitlements, Info.plist keys, ATS)
- [ ] All validation commands pass; no regressions
- [ ] `docs/api-contract.md` updated where hardening exposed gaps (e.g. suspension code, Firebase wording)

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full unit and UI suites pass locally and in Xcode Cloud
- [ ] Findings logged against owning plans and resolved
- [ ] Manual App Store Connect steps done or ticketed

## NOTES
- This plan is verification-heavy by design: prefer fixing issues in the owning plan's files and re-running the relevant audit.
- `performAccessibilityAudit` cannot judge semantics; the manual VoiceOver pass is mandatory.
- PhotosPicker needs no photo-library permission; do not add `NSPhotoLibraryUsageDescription` unless direct `PHPhotoLibrary` access is introduced (extra permission strings invite review questions).
- Under default MainActor isolation, background-queue callbacks (`NWPathMonitor`, delegate methods) must be `nonisolated` and hop to `MainActor` explicitly.
- Spanish localization is post-launch (PRD §5): keep the catalog structure ready (plurals, no concatenation) but ship `en` only.
