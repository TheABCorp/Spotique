# Feature: Push Notifications (APNs Registration, Permission Priming, Deep Links, Preferences)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities, and import from the right files. Names owned by other plans (`HostInboxRoute`, the driver booking-detail route, `RatingRoute`) must be read from those plans' final code, not assumed.

**Source:** `docs/prd-v1.md` §4.7 (P0 Required + P1 Additional Notifications), §4.3 acceptance criteria (deep link to request), §4.8 (notification preferences), §7.1 (delivery ≤ 5 s), §7.2; `docs/api-contract.md` (Bookings side effects); `iOS/plans/README.md` gaps 3, 5, 9.

## Feature Description

Register the device for APNs after sign-in, ask for notification permission at a moment with context (not at cold launch), and translate incoming pushes into in-app navigation. Covers: `AppDelegate` adaptor for APNs callbacks, `DeviceServicing` (register/unregister token), foreground presentation, badge count, the notification catalogue (payload schema the server must send), `NotificationRouter` (payload -> `AppRouter.pendingDeepLink`), cold-start and signed-out handling, denied-state handling, and a per-type preferences screen that plan 13 embeds in Settings.

## User Story

As a host or driver / I want to be notified the moment a booking request, confirmation, decline, reminder, or rating prompt happens, and land directly on the relevant screen / So that I respond quickly and never have to hunt through the app.

## Problem Statement

Bookings are asynchronous: a host may be away from the app when a request arrives and a driver waits on the answer. Without push, the marketplace stalls (PRD §3 response-time goals). There is no device-token endpoint in the contract, no deep-link plumbing, and no preference storage.

## Solution Statement

- **Server sends every notification** (single source of truth, works when the app was never reopened, preferences enforced centrally). Client owns registration, presentation, routing.
- Standard (non-provisional) authorization requested via a **priming sheet** after the first meaningful action; provisional rejected (quiet delivery defeats time-sensitive booking requests).
- `AppDelegate` is a thin bridge; all logic lives in `@MainActor @Observable NotificationManager` and pure, testable `NotificationRouter`/`PushPayload` parsing.
- Everything behind protocols (`DeviceServicing`, `NotificationCenterClient`) so simulators (which cannot receive real APNs) and tests use fakes and `xcrun simctl push`.

## Requirements & Acceptance Criteria

Verbatim PRD tables (message copy is exact; `[Name]` = counterpart first name supplied by the server):

| Trigger | Recipient | Message | `type` | Target route |
|---------|-----------|---------|--------|--------------|
| P0 New booking request received | Host | "[Name] wants to park Sat 2–5pm. Tap to respond." | `booking_request` | Host inbox request detail (`HostInboxRoute.request(bookingID)`, plan 09) |
| P0 Booking confirmed by host | Driver | "Booking confirmed! Tap to see full address and host contact." | `booking_confirmed` | Driver booking detail (plan 06) |
| P0 Booking declined by host | Driver | "Your request was declined. Try another spot nearby." | `booking_declined` | Driver booking detail (plan 06) |
| P0 Rating window opens (48h post-booking) | Both | "How was your experience with [Name]? Rate them now." | `rating_open` | Rating sheet (`RatingRoute.rate(bookingID)`, plan 12) |
| P1 30 min after start, driver not arrived | Host | "Driver hasn't shown up? Tap to report a no-show." | `no_show_prompt` | Host booking detail with no-show prompt (plans 10/12) |
| P1 1 hour before booking start | Driver | "Your Spotique booking starts in 1 hour." | `booking_reminder` | Driver booking detail (plan 06) |
| P1 No-show reported by host | Driver | "[Host] reported you didn't arrive for your booking." | `no_show_reported` | Driver booking detail (plan 06) |

Acceptance criteria from the PRD: "Push notification sent to host within 5 seconds of new booking request" (server; client verifies receipt manually); "Tapping notification deep-links to the specific request"; "Push notification sent on host accept or decline"; PRD §7.2 "Push registration only after the user has been verified" (ios-security-review). §4.8 "Push notification preferences (per notification type)".

Client-derived criteria:
- Permission is never requested at cold launch; requested from the priming sheet after (a) the driver's first submitted booking request or (b) the host's first published listing.
- Denied state shows a non-blocking banner with an "Open Settings" action; the system prompt is never re-triggered (iOS only shows it once).
- Token registered after sign-in and re-sent each launch; unregistered on sign-out.
- Tapping a push while signed out/profile-incomplete stores the route and navigates after sign-in completes.
- Payloads and deep links are untrusted input: validate `type`, id format, recipient.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium-High (cross-plan integration; no server support yet)
**Platforms**: iOS (Api needs `/devices` + preferences + push sender; Android out of scope)
**Primary Systems Affected**: `App/`, `Features/Notifications/`, `Services/`, `AppRouter`, `SessionStore` sign-out hook, entitlements
**Dependencies**: `UserNotifications`, `UIKit` (`UIApplicationDelegateAdaptor`). No third-party SDK (no Firebase/FCM per README gap 1).

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `iOS/plans/01-foundation.md` "CREATE App/AppRouter.swift, RootView.swift, SpotiqueApp.swift" and "CREATE Core/Auth/SessionStore.swift" — `pendingDeepLink`, `selectedTab`, state transitions.
- `iOS/plans/01-foundation.md` "CREATE App/AppEnvironment.swift" — add `deviceService`, `notificationManager` one line each.
- `iOS/plans/09-host-booking-inbox.md` — `HostInboxRoute.request(bookingID)`, pending count for the badge.
- `iOS/plans/06-driver-bookings.md`, `10-booking-history.md` — booking-detail route and how a booking is loaded by id (gap 5).
- `iOS/plans/12-ratings-and-no-show.md` — `RatingRoute`, no-show prompt.
- `iOS/plans/13-profile-and-settings.md` — Settings hosts the preferences link.
- `iOS/plans/05-request-booking.md`, `07-host-listing-creation.md` — priming trigger call sites.
- `iOS/Spotique/SpotiqueApp.swift` (after plan 01) — where the adaptor attaches.

### New Files to Create
```
iOS/Spotique/App/AppDelegate.swift                               UIApplicationDelegate: APNs token callbacks, UNUserNotificationCenter delegate
iOS/Spotique/Services/DeviceService.swift                        DeviceServicing + LiveDeviceService
iOS/Spotique/Services/NotificationPreferencesService.swift       NotificationPreferencesServicing + Live
iOS/Spotique/Models/NotificationPreferences.swift                per-type flags
iOS/Spotique/Features/Notifications/PushPayload.swift            Sendable parsed payload + NotificationType enum
iOS/Spotique/Features/Notifications/DeepLink.swift               DeepLink enum (AppRouter.pendingDeepLink type)
iOS/Spotique/Features/Notifications/NotificationRouter.swift     payload -> DeepLink -> AppRouter
iOS/Spotique/Features/Notifications/NotificationCenterClient.swift  protocol over UNUserNotificationCenter
iOS/Spotique/Features/Notifications/NotificationManager.swift    @Observable: auth state, token, registration, badge, foreground events
iOS/Spotique/Features/Notifications/NotificationPermissionCoordinator.swift  priming rules (context, cool-down)
iOS/Spotique/Features/Notifications/NotificationPrimingSheet.swift
iOS/Spotique/Features/Notifications/NotificationsDisabledBanner.swift  denied-state banner + Settings deep link
iOS/Spotique/Features/Notifications/NotificationPreferencesView.swift / NotificationPreferencesViewModel.swift
iOS/Spotique/Spotique.entitlements                               aps-environment
iOS/SpotiqueTests/Fakes/{FakeDeviceService,FakeNotificationCenterClient,FakeNotificationPreferencesService}.swift
iOS/SpotiqueTests/Fixtures/push/{booking_request,booking_confirmed,booking_declined,rating_open,no_show_prompt,booking_reminder,no_show_reported}.apns   simctl payloads
iOS/SpotiqueTests/{PushPayloadTests,NotificationRouterTests,NotificationManagerTests,NotificationPermissionCoordinatorTests,DeviceServiceTests,NotificationPreferencesViewModelTests}.swift
```

### Documentation — READ BEFORE IMPLEMENTING
- [Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) — `registerForRemoteNotifications`, token callbacks; token can change, request every launch.
- [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) — provisional vs standard, one-time prompt.
- [Handling notifications and notification-related actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions) — `willPresent`, `didReceive`, cold-launch delivery of the response.
- [Generating a remote notification](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification) and [Sending push notifications using command-line tools](https://developer.apple.com/documentation/usernotifications/sending-push-notifications-using-command-line-tools) — payload keys, `xcrun simctl push`.
- `UIApplication.openNotificationSettingsURLString` (iOS 16+) — deep link to this app's notification settings.
- `docs/api-contract.md` § Bookings (side effects), § Error Format.

### Skills to Apply
`mvvm-architecture` (protocol DI), `swiftui-development` (sheets, banners, a11y), `ios-security-review` (payload validation, no PII in notifications, register only after verified), `swift-concurrency-6-2` (delegate callbacks are nonisolated; project default is MainActor), `ios-debugging` (push troubleshooting), `spotique-brand-ui`, `xcode-cloud` (capability/signing).

### Patterns to Follow
- Service: `protocol DeviceServicing: Sendable` + `struct LiveDeviceService` taking `APIClient` (plan 01 Patterns).
- Logging: `Log.network`/`Log.ui`; never log the device token in full (`privacy: .private`) or payload bodies.
- Delegate methods run off the main actor: extract a `Sendable` `PushPayload` from `userInfo` inside a `nonisolated` method, then `await MainActor.run`/`Task { @MainActor in }`. `UNNotificationResponse` and `[AnyHashable: Any]` are not `Sendable`.

---

## PRIVACY & SECURITY

- **Notification content must never contain the full address or host/driver phone.** Lock-screen text is visible pre-unlock. The contract says confirm sends a push "with address" (`api-contract.md` Bookings side effects) — **contradicts** PRD copy ("Tap to see full address") and the privacy model. Requirement to server: payload carries only `type`, `booking_id`, ids and the PRD copy; the address is fetched after tap over the authenticated API. Client parser rejects/ignores unknown keys and never persists `userInfo`.
- Allowed payload personal data: counterpart **first name** and date/time window (PRD copy requires them). Consider `UNNotificationInterruptionLevel.timeSensitive` for `booking_request`/`booking_reminder` only (needs the Time Sensitive capability — open question).
- Registration requires an authenticated session; token upload only when `SessionStore.state == .signedIn`. Unregister before the JWT is cleared. On 401-triggered sign-out unregister cannot succeed; the server must (a) prune tokens on APNs `410 Unregistered`, (b) reassign a token to the newest authenticated user on register (shared devices).
- Treat push and deep links as untrusted: `booking_id` must match `^[A-Za-z0-9_-]{1,64}$`; ignore `type` not in the catalogue; require signed-in session before acting; optional `recipient_id` must equal the current user else drop (account switched on device). The destination screen still authorizes via the API (403/404 -> "This booking is no longer available").
- Local notifications (if the reminder fallback is enabled): generic copy, no address, no phone, identifier `reminder-<bookingID>`, removed on sign-out.
- Delivered notifications cleared on sign-out (`removeAllDeliveredNotifications`, badge 0).
- APNs auth key (.p8) is server-side only; nothing APNs-secret in the app.

## IMPLEMENTATION PLAN

### Phase 1: Foundation — models, payload schema, protocols, entitlement
### Phase 2: Core — manager, router, delegate, device + preferences services
### Phase 3: Integration — permission priming triggers (plans 05/07), sign-in/out hooks (plan 01/02/13), inbox badge (plan 09), deep-link consumption (plans 06/09/12), Settings link (plan 13)
### Phase 4: Testing & validation (unit + `simctl push` manual)

### Payload schema the server MUST send (v1)
```json
{
  "aps": {
    "alert": { "title": "Spotique", "body": "Alex wants to park Sat 2–5pm. Tap to respond." },
    "sound": "default", "badge": 3, "thread-id": "booking_456", "category": "booking_request"
  },
  "type": "booking_request",      // catalogue key above
  "booking_id": "booking_456",    // required for all 7 types
  "recipient_id": "uid_abc123",   // optional; recommended
  "v": 1
}
```
`aps.category` == `type`. `thread-id` == `booking_id` groups a booking's notifications. `badge` = host's current pending-request count (0 for drivers) — decision assumed; open question 6. Title uses the app name; body is the PRD copy verbatim, localized by the server from the user's language (client should send `Accept-Language` — plan 01 note).

### Server vs. locally scheduled (evaluation and recommendation)
| | Server push | Local `UNCalendarNotificationTrigger` |
|--|--|--|
| +30 min host no-show prompt | **Server.** Must suppress when the driver arrived/marked (state only the server knows; client cannot cancel a local one reliably) and when already reported | Rejected: would fire even after arrival; host may never open the app after accepting |
| 1 h driver reminder | **Server (primary)**: works if the driver never reopens the app, honors preferences, handles cancellation | Viable **fallback only**: schedule on booking-confirmed sync, cancel on cancel/sign-out; no address. Risk: never scheduled if app isn't opened after confirmation; duplicates with server push |
Recommendation: server for all seven. Ship the local 1 h reminder only if the server cannot deliver it for MVP (task marked OPTIONAL, behind `FeatureFlags.localReminder`, dedupe by removing the local one when a `booking_reminder` push for the same booking arrives).

---

## STEP-BY-STEP TASKS

Run from `iOS/`. Test command shape: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests/<Suite>`.

### CREATE Features/Notifications/PushPayload.swift
- **IMPLEMENT**: `nonisolated enum NotificationType: String, Sendable { bookingRequest = "booking_request", bookingConfirmed, bookingDeclined, ratingOpen, noShowPrompt, bookingReminder, noShowReported }` (snake_case raw values) and `nonisolated struct PushPayload: Sendable, Equatable { type, bookingID, recipientID? }` with `init?(userInfo: [AnyHashable: Any])` validating `type` (known), `booking_id` (regex), `v` (ignore > known max leniently).
- **PATTERN**: unknown-tolerant enums in plan 01 `Enums.swift`.
- **GOTCHA**: `userInfo` is `[AnyHashable: Any]`; parse in a `nonisolated` initializer so delegate threads can call it.
- **VALIDATE**: `... -only-testing:SpotiqueTests/PushPayloadTests` (valid x7, missing id, bad id chars, unknown type, extra keys ignored).

### CREATE Features/Notifications/DeepLink.swift and UPDATE App/AppRouter.swift
- **IMPLEMENT**: `enum DeepLink: Hashable, Sendable { hostRequest(bookingID), booking(bookingID), rate(bookingID), noShowPrompt(bookingID) }`. Set `AppRouter.pendingDeepLink: DeepLink?` (plan 01 declares the property; this task fixes its type) plus `func consumeDeepLink() -> DeepLink?`.
- **GOTCHA**: plan 01 must not type it as `URL`/`String`; see NOTES for the required plan 01 edit.
- **VALIDATE**: `AppRouterTests` (set, consume-once).

### CREATE Features/Notifications/NotificationRouter.swift
- **IMPLEMENT**: `@MainActor struct NotificationRouter { func route(_ payload: PushPayload, currentUser: User?) -> DeepLink? }`: booking_request -> `.hostRequest` (only if role host/both; otherwise `.booking`), booking_confirmed/declined/reminder/no_show_reported -> `.booking`, rating_open -> `.rate`, no_show_prompt -> `.noShowPrompt`; drop on `recipientID` mismatch. `func handle(_ payload:, router: AppRouter, session: SessionStore)`: always set `router.pendingDeepLink`; `MainTabView` (plans 06/09) observes and consumes only when `session.state == .signedIn`, selects the tab (host inbox tab for `.hostRequest`; Bookings tab otherwise; `.rate` presented as sheet from `MainTabView` via plan 12's `AppRouter.ratingSheet`) and appends the route to that tab's `NavigationPath`.
- **PATTERN**: typed navigation paths per tab (plan 01 AppRouter).
- **GOTCHA**: cold start. `didReceive` can be delivered before `SpotiqueApp` has built `AppEnvironment`. `AppDelegate` therefore buffers into `PendingPushBuffer.shared` (nonisolated, lock-protected) and `NotificationManager.attach(router:session:)` drains it in the app's first `.task`. Keep the link across `.launching`, `.signedOut`, `.needsProfile`; consume only at `.signedIn`. Discard links older than 30 min.
- **VALIDATE**: `... -only-testing:SpotiqueTests/NotificationRouterTests` (each type x role, signed-out retention, account mismatch dropped, cold-start buffer drain order).

### CREATE Services/DeviceService.swift
- **IMPLEMENT**: `protocol DeviceServicing: Sendable { func register(token: String, environment: APNsEnvironment) async throws; func unregister(token: String) async throws }`. Live: **proposed** `POST /devices` body `{ "device": { "token": "<hex>", "platform": "ios", "environment": "sandbox|production", "app_version": "1.0" } }` -> 204/201 upsert (server moves token to caller); `DELETE /devices/:token` -> 204 (idempotent). `APNsEnvironment` = `#if DEBUG .sandbox #else .production` (TestFlight/App Store use production).
- **GOTCHA**: endpoints are NOT in the contract (README gap 3); add to `docs/api-contract.md` when agreed. Until the API exists `LiveDeviceService` failures must be swallowed with a `Log.network` warning (never block sign-in); retry next launch.
- **VALIDATE**: `... -only-testing:SpotiqueTests/DeviceServiceTests` with `StubURLProtocol` (paths, methods, body shape, 404 tolerated).

### CREATE Features/Notifications/NotificationCenterClient.swift
- **IMPLEMENT**: `protocol NotificationCenterClient: Sendable` wrapping `authorizationStatus() async -> PushAuthorization` (`notDetermined, denied, authorized, provisional, ephemeral`), `requestAuthorization() async throws -> Bool` (options `[.alert, .sound, .badge]`), `setBadge(_:)` (`setBadgeCount`), `removeDelivered(threadID:)`, `removeAllDelivered()`, `registerCategories()`. Live wraps `UNUserNotificationCenter.current()`; fake for tests.
- **VALIDATE**: build; exercised via manager tests.

### CREATE Features/Notifications/NotificationManager.swift
- **IMPLEMENT**: `@Observable @MainActor final class NotificationManager` with state `authorization: PushAuthorization`, `deviceToken: String?`, `pendingRequestCount: Int`; actions `refreshAuthorization()`, `requestAuthorization()`, `sessionDidSignIn()` (if authorized/provisional call `registerForRemoteNotifications()`, then register token), `sessionWillSignOut() async` (unregister, clear badge/delivered), `didReceiveDeviceToken(_ data: Data)` (hex string), `didFailToRegister(_:)`, `setPendingRequestCount(_:)` (sets badge, called by plan 09), `foregroundEvents: AsyncStream<PushPayload>` that plans 06/09 view models `for await` to refetch. Re-register on every launch after sign-in and on `.authorized` transitions; skip upload if same `(userID, token)` already sent this session.
- **GOTCHA**: `registerForRemoteNotifications()` is allowed before authorization but tokens are only useful once authorized. Call it from `sessionDidSignIn()` and again after the grant. Foreground presentation (`willPresent`): return `[.banner, .list, .sound, .badge]`, except suppress the banner when the payload's target is the visible screen (router exposes `currentBookingID`), and always yield to `foregroundEvents`. Opening a booking detail calls `removeDelivered(threadID: bookingID)`.
- **VALIDATE**: `... -only-testing:SpotiqueTests/NotificationManagerTests` (token hex formatting, register on sign-in only when authorized, no upload while signed out, unregister before clear, failure swallowed, badge set, duplicate suppression).

### CREATE App/AppDelegate.swift and UPDATE App/SpotiqueApp.swift
- **IMPLEMENT**: `final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate`. In `application(_:didFinishLaunchingWithOptions:)` set `UNUserNotificationCenter.current().delegate = self` **synchronously** (required to receive the cold-launch tap) and register categories (one per `type`, no actions in MVP). Implement `didRegisterForRemoteNotificationsWithDeviceToken`, `didFailToRegisterForRemoteNotificationsWithError`, async `userNotificationCenter(_:willPresent:)` and `(_:didReceive:)`. `SpotiqueApp`: `@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate`; in `.task` call `notificationManager.attach(...)` which hands the manager to the delegate and drains buffered token/tap.
- **PATTERN**: [UIApplicationDelegateAdaptor](https://developer.apple.com/documentation/swiftui/uiapplicationdelegateadaptor).
- **GOTCHA**: the delegate is created before `AppEnvironment` exists — no direct env access; use `PendingPushBuffer`. Do no network in `didFinishLaunching` (cold launch <= 3 s, plan 14). Don't add Background Modes > remote-notification (no silent pushes in MVP).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; manual `simctl push` (below).

### CREATE Spotique.entitlements and UPDATE project settings
- **IMPLEMENT**: entitlement `aps-environment = development` (Xcode/Xcode Cloud signing swaps to `production` at archive); set `CODE_SIGN_ENTITLEMENTS = Spotique/Spotique.entitlements`; enable Push Notifications on the App ID (manual, App Store Connect/Developer portal).
- **GOTCHA**: the simulator ignores entitlement for `simctl push`, but a device build without the capability fails registration with "no valid aps-environment". Not used: Time Sensitive Notifications (open question).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`; `grep -c aps-environment Spotique/Spotique.entitlements`.

### CREATE Features/Notifications/NotificationPermissionCoordinator.swift, NotificationPrimingSheet.swift, NotificationsDisabledBanner.swift
- **IMPLEMENT**: `@Observable @MainActor final class NotificationPermissionCoordinator` with `func offerIfAppropriate(context: PrimingContext) async` where `PrimingContext = .firstBookingRequest | .firstListingPublished | .inboxOpened`. Shows the sheet only when status is `.notDetermined` and priming not shown in the last 7 days (max 2 times, stored as `primingShownCount`/`lastShownAt` in `UserDefaults`, keyed per user; non-sensitive). Sheet copy is role-aware (host: "Get notified the moment a driver requests your spot"; driver: "Know right away when your request is accepted"), buttons "Turn On Notifications" (-> system prompt) and "Not Now" (no system prompt consumed). Denied: `NotificationsDisabledBanner` (used in host inbox plan 09, My Bookings plan 06, preferences screen) with "Open Settings" -> `UIApplication.openNotificationSettingsURLString`. Authorized-after-priming triggers `registerForRemoteNotifications()`.
- **Call sites**: plan 05 calls `offerIfAppropriate(.firstBookingRequest)` after a successful submit (after the success state renders); plan 07 after publish success; plan 09 inbox for hosts who declined earlier -> banner only.
- **GOTCHA**: the sheet must not stack on top of the plan 05/07 success screens; present when they dismiss. Never call `requestAuthorization` at launch or in `init`. Brand copy neutral; no dark patterns; "Not Now" equal visual weight (44pt).
- **VALIDATE**: `... -only-testing:SpotiqueTests/NotificationPermissionCoordinatorTests` (fires once per context, respects cool-down, silent when denied/authorized, count cap, reset on sign-out).

### CREATE Models/NotificationPreferences.swift, Services/NotificationPreferencesService.swift
- **IMPLEMENT**: `NotificationPreferences` (Codable) with Bool per `NotificationType`. **Proposed API** (not in contract, README gap 9): `GET /users/me/notification_preferences` -> `{ "data": { "booking_request": true, "booking_confirmed": true, ... } }`; `PATCH` same shape with partial keys. `LocalNotificationPreferencesStore` (UserDefaults keyed by user id) as fallback so the UI works before the API exists.
- **GOTCHA**: the fallback cannot stop remote pushes delivered while backgrounded; it only filters foreground presentation. Real enforcement is server-side. Document in UI-free code comment and in Open Questions.
- **VALIDATE**: `... -only-testing:SpotiqueTests/NotificationPreferencesViewModelTests`.

### CREATE Features/Notifications/NotificationPreferencesView.swift / ViewModel
- **UI contract consumed by plan 13**: `NotificationPreferencesView(environment: AppEnvironment)` — a pushable screen (no own NavigationStack), plan 13 adds `NavigationLink("Notifications") { NotificationPreferencesView(...) }` in Settings. Sections by role from `SessionStore.currentUser.role`: Host — New booking requests (`booking_request`), No-show prompt (`no_show_prompt`); Driver — Booking confirmed, Booking declined, Reminder 1 hour before, No-show reported (`booking_confirmed`, `booking_declined`, `booking_reminder`, `no_show_reported`); Everyone — Rating reminders (`rating_open`). Role `both` shows all. `Toggle` per type with human labels + footers; optimistic update with rollback and `ErrorBanner` on failure; when OS authorization is denied show `NotificationsDisabledBanner` on top and disable toggles' explanatory text ("Notifications are off in iOS Settings").
- **State**: `State { loading, loaded, failed(APIError) }`, `preferences`, `isSaving: Set<NotificationType>`; actions `load()`, `set(_:enabled:)`. Turning off `booking_request` or `booking_confirmed` shows a one-time confirmation dialog ("You may miss booking requests").
- **A11y**: toggles labelled with the full title; footers read as hints; Dynamic Type up to accessibilityXXXL wraps.
- **VALIDATE**: `... -only-testing:SpotiqueTests/NotificationPreferencesViewModelTests` (load, toggle success/rollback, role-based sections).

### UPDATE App/AppEnvironment.swift and SessionStore hooks
- **IMPLEMENT**: add `deviceService`, `notificationPreferencesService`, `notificationManager`, `notificationPermissionCoordinator` (live + preview). `SessionStore` gains an ordered async `willSignOut` hook list (plan 01 edit): `signOut()` first awaits `notificationManager.sessionWillSignOut()` (needs the still-valid JWT), then clears token/user/caches. After `.signedIn` transition call `sessionDidSignIn()`.
- **GOTCHA**: sign-out triggered by a 401 skips network unregister (token invalid) — still clear local badge/delivered.
- **VALIDATE**: `... -only-testing:SpotiqueTests/SessionStoreTests -only-testing:SpotiqueTests/NotificationManagerTests`.

### CREATE simctl payload fixtures
- **IMPLEMENT**: one `.apns` JSON per type (with `"Simulator Target Bundle": "com.actionman.Spotique"`), same schema as above.
- **VALIDATE** (manual): `xcrun simctl push booted com.actionman.Spotique SpotiqueTests/Fixtures/push/booking_request.apns` — foreground -> banner; background tap -> lands on request; terminate app (`xcrun simctl terminate booted com.actionman.Spotique`), push, tap -> cold-start routing; signed-out tap -> route retained until sign-in.

### OPTIONAL CREATE Features/Notifications/LocalReminderScheduler.swift
- **IMPLEMENT**: only if server cannot send `booking_reminder`. Schedule `UNCalendarNotificationTrigger` at `startTime - 1h` for confirmed driver bookings when bookings sync; body exactly the PRD copy; identifier `reminder-<bookingID>`; cancel on non-confirmed status/sign-out; skip if start within 1 h.
- **VALIDATE**: unit test with fake center (scheduled, replaced, cancelled).

---

## TESTING STRATEGY

### Unit Tests
Swift Testing suites listed above; deterministic fakes for `NotificationCenterClient`, `DeviceServicing`, preferences service; `@MainActor` types awaited. No real APNs, no `sleep`.

### Integration / Manual
`simctl push` matrix: 7 types x {foreground, background, terminated} x {host, driver, both} x {signed in, signed out, profile incomplete}. Real-device pass with a sandbox APNs sender (dev build) once server endpoints exist: verify token registration, <= 5 s latency (server metric), badge, thread grouping, denied/allowed flows, Settings deep link, delete-and-reinstall.

### Edge Cases
Permission denied then re-enabled in Settings (refresh authorization on `scenePhase == .active`); token rotates; two accounts on one device; push for booking already cancelled/removed (404 screen); tap while another modal is presented (dismiss/queue); malicious/unknown payload; duplicate delivery; app in background killed by user (no pushes until reopened is OS behavior); locale change; Focus modes; notification arrives while the target screen is open (no banner, refetch only).

## VALIDATION COMMANDS
### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`
### Level 3: Integration
`xcrun simctl push booted com.actionman.Spotique <fixture>.apns` for each fixture (see task above).
### Level 4: Manual
Real device: priming flow after first request/listing; deny path + Settings link; sign-out unregisters (server shows token removed); verify lock-screen text contains no address/phone; grep: `grep -rn "print(" Spotique/Features/Notifications Spotique/App`.

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Device-token endpoints (`POST /devices`, `DELETE /devices/:token`) and APNs sender on Rails | README gap 3 | Pending; proposed here |
| 2 | Contract says confirm push includes address; PRD/privacy say no. Confirm payload excludes address | Contract vs PRD §4.7/§7.2 | Assumed excluded |
| 3 | Notification preferences API (`/users/me/notification_preferences`) | README gap 9 | Pending; local fallback |
| 4 | No `GET /bookings/:id` for tap destinations | README gap 5 | Plans 06/09/10 resolve via list; needs endpoint |
| 5 | Rating notification timing (48 h after end == window close) | PRD §4.6 vs §4.7 | See plan 12; client agnostic |
| 6 | Badge semantics (host pending count only?) | Discovered | Assumed |
| 7 | Time Sensitive interruption level for requests/reminders (extra capability, review implications)? | Discovered | Deferred |
| 8 | Auto-decline after 24 h (PRD Q2) would need a "request expired" notification type | PRD §8 Q2 | Not in catalogue |
| 9 | "Driver arrived" state is required to suppress `no_show_prompt` (no endpoint) | README gap 8 | See plan 12 |
| 10 | Should P0 types be user-disableable? | PRD §4.8 says per type | Allowed with warning |

## ACCEPTANCE CRITERIA
- [ ] No permission request at cold launch; priming appears after first request/listing only
- [ ] Denied state shows banner and working "Open Settings"
- [ ] Token registered after sign-in (authorized), re-sent per launch, unregistered on sign-out before token cleared
- [ ] All 7 catalogue types route to the specified screen; cold start and signed-out cases handled
- [ ] Untrusted payloads validated; account-mismatch dropped
- [ ] Foreground presentation, badge, thread grouping, delivered cleanup work
- [ ] Preferences screen embeddable by plan 13 and role-aware
- [ ] Notification content has no address/phone; documented server requirement
- [ ] All validation commands pass; no regressions; conventions followed
- [ ] `docs/api-contract.md` updated with device and preference endpoints once agreed

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Manual `simctl push` matrix executed; real-device pass recorded when server is ready
- [ ] Open questions recorded with decisions

## NOTES
- **Required edits to plan 01**: type `AppRouter.pendingDeepLink` as `DeepLink?` (defined here); add `SessionStore` async sign-out hooks; add `notificationManager`/`deviceService` to `AppEnvironment`.
- Under default MainActor isolation the `AppDelegate` is MainActor-isolated; UN delegate callbacks must be declared `nonisolated` (or use the async overloads) and parse into `Sendable` values before hopping.
- Provisional authorization was rejected: booking requests are time-sensitive and quiet delivery hides them in Notification Center.
- Actionable notifications (Accept/Decline from the lock screen, "Report no-show") are deliberately out of MVP: they require authenticated background API calls and raise mistaken-tap risk. Categories are registered now so actions can be added without server changes.
- "Rating window opens (48h post-booking)" copy assumes the reconciliation in plan 12; the client only needs `rating_open` + `booking_id`.
- Android/FCM is out of scope; the payload schema is transport-neutral for a later FCM mapping.
