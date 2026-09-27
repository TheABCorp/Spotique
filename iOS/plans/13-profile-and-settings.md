# Feature: iOS Profile & Settings (Profile, Edit, Role Toggle, Settings, Log Out, Delete Account)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities, and import from the right files. Shared types (`SessionStore`, `AppRouter`, `UserServicing`, `AppEnvironment`, design-system components) come from [01-foundation](01-foundation.md); `RolePickerView` and `ProfileValidation` from [02-auth-onboarding](02-auth-onboarding.md); `RatingSummaryView` from plan 04; booking history list from plan 10; listing rows from plans 07/08; notification preferences depend on plan 11.

**Source:** `docs/prd-v1.md` §4.8 (P1 User Profile, P1 Settings), §4.1 (role changeable later), §4.6, §7.2, §7.3; `docs/api-contract.md` § `PATCH /users/me`, `DELETE /users/me`.

## Feature Description

The **Profile** tab shows the signed-in user's identity and trust data, lets them edit name/address, switch role (Host / Driver / Both), and reach booking history and (for hosts) active listings. **Settings** holds push notification preferences, host payment method text, log out, and delete account. Role changes immediately change which tabs appear.

## User Story

As a Spotique user, I want to manage my profile, role, and account settings, so that I stay in control of my identity, how I use the app, and my data.

## Problem Statement

After onboarding (plan 02), users have no way to correct their name or address, change role (PRD: "Role selection can be changed later in Settings"), set the payment text drivers see after confirmation, sign out, or delete their account (an App Store requirement for apps that support account creation).

## Solution Statement

`Features/Profile/` with `ProfileView` (read-only summary + sections composed from other plans' components), `EditProfileView` (name/address), `SettingsView` (role, payment text, notification prefs shell, log out, delete). All writes go through `UserServicing.update(_:)` (`PATCH /users/me`, only changed fields) and update `SessionStore.update(user:)`, which is the single source for tab visibility. Delete calls `DELETE /users/me`, then `SessionStore.signOut()`.

## Requirements & Acceptance Criteria

**PRD §4.8 — P1 User Profile (verbatim)**
- First name and last name (editable)
- Home address (editable)
- Rating summary (positive % + total booking count)
- No-show count (drivers only)
- Role toggle (Host / Driver / Both)
- Active listings section (hosts only)
- Booking history (all users)

**P1 Settings (verbatim)**
- Push notification preferences (per notification type)
- Payment method display text (hosts — shown to drivers after confirmation)
- Log out
- Delete account (deletes Firestore user document and anonymizes booking records)

**Contract**: `PATCH /users/me` body `{ "user": { first_name?, last_name?, address?, role?, payment_method_text? } }`, only changed fields; 200 → user object. `DELETE /users/me` → 204. Validation (from §4.1/Rails `User`): names 1–50 chars, address required, role in `host|driver|both`.
**Derived criteria**: role change updates tabs immediately; log out and delete clear Keychain token, session snapshot, and caches; destructive actions require explicit confirmation; no-show count is shown to drivers/both only.

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium
**Platforms**: iOS (Api: `PATCH`/`DELETE /users/me` not yet implemented — only `/auth/*` routes exist in `Api/config/routes.rb`)
**Primary Systems Affected**: `Features/Profile/`, `Core/Auth/SessionStore.swift`, `App/RootView.swift` (tab visibility), `Services/UserService.swift`, `Localizable.xcstrings`
**Dependencies**: Plans 01, 02; plan 04 (`RatingSummaryView`), 07/08 (listing rows + "my listings" source), 10 (booking history list), 11 (notification preferences and OS permission state). Build against fakes until they land.

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `iOS/Spotique/Services/UserService.swift` (plan 01) — `UserServicing.update(_:)`, `deleteAccount()`.
- `iOS/Spotique/Core/Auth/SessionStore.swift` — `update(user:)`, `signOut()`, `currentUser`; `iOS/Spotique/App/AppRouter.swift` — `selectedTab`; `App/RootView.swift` — `MainTabView` tab set by `user.role`.
- `iOS/Spotique/Features/Auth/{ProfileValidation,RolePickerView}.swift` (plan 02) — reuse, do not fork.
- `iOS/Spotique/Features/Ratings/RatingSummaryView.swift` (plan 04/12 — confirm final path), `Features/History/BookingHistoryView.swift` (plan 10), listing row view from plans 07/08.
- `iOS/Spotique/Core/DesignSystem/Components/*` — `Card`, `PrimaryButton`, `SecondaryButton`, `ErrorBanner`, `EmptyStateView`, `LoadingOverlay`.
- `iOS/Spotique/Models/{User,Enums}.swift` — `User` fields: `firstName, lastName, address, role, ratingPositivePct, ratingCount, noShowCount, paymentMethodText, phone?, email?`.
- `Api/app/models/user.rb` (validations: names 1–50, role inclusion), `Api/app/controllers/concerns/require_complete_profile.rb`.

### New Files to Create
```
iOS/Spotique/Features/Profile/ProfileView.swift
iOS/Spotique/Features/Profile/ProfileViewModel.swift
iOS/Spotique/Features/Profile/EditProfileView.swift
iOS/Spotique/Features/Profile/EditProfileViewModel.swift
iOS/Spotique/Features/Profile/SettingsView.swift
iOS/Spotique/Features/Profile/SettingsViewModel.swift
iOS/Spotique/Features/Profile/RoleSettingsSection.swift          (role toggle UI + confirm sheet)
iOS/Spotique/Features/Profile/PaymentMethodEditor.swift
iOS/Spotique/Features/Profile/NotificationPreferencesView.swift  (UI shell; data via plan 11 protocol)
iOS/Spotique/Features/Profile/NotificationPreferencesViewModel.swift
iOS/Spotique/Features/Profile/DeleteAccountFlow.swift            (confirmation sheet + state)
iOS/Spotique/Features/Profile/UserRole+Display.swift             (tab visibility helpers: showsListingsTab, showsExploreTab, showsNoShowCount)
iOS/SpotiqueTests/Fakes/FakeUserService.swift                    (extend plan 01's)
iOS/SpotiqueTests/Fakes/FakeNotificationPreferencesService.swift
iOS/SpotiqueTests/{ProfileViewModelTests,EditProfileViewModelTests,SettingsViewModelTests,NotificationPreferencesViewModelTests,RoleTabVisibilityTests,DeleteAccountTests}.swift
iOS/SpotiqueUITests/ProfileSettingsUITests.swift
```

### Documentation — READ BEFORE IMPLEMENTING
- `docs/api-contract.md` § `PATCH /users/me`, `DELETE /users/me`, § Enums.
- `docs/prd-v1.md` §4.8, §4.7 (notification types), §4.6 (rating stats), §7.3, §8.
- Apple: [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/) (App Review 5.1.1(v)), [`confirmationDialog`](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)), [`UNUserNotificationCenter.getNotificationSettings`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/notificationsettings()).

### Skills to Apply
`mvvm-architecture`, `swiftui-development` (lists/forms, alerts, accessibility), `spotique-brand-ui`, `liquid-glass-design` (toolbar/tab), `ios-api-client`, `ios-security-review` (sign-out data wipe, delete), `swift-concurrency-6-2`.

### Patterns to Follow
Same ViewModel/service/logging patterns as plan 01/02: `@Observable @MainActor final class`, `State` enum for the submit lifecycle, `APIError` mapped to localized text, `Log.auth`/`Log.ui` without PII. Field validation delegates to `ProfileValidation`.

---

## PRIVACY & SECURITY

- The profile shows the user's **own** phone/email and home address only; nothing on these screens exposes another user's address or phone. The user's `address` here is a home address, never a listing address.
- Do not cache the profile beyond the session snapshot (Keychain, plan 02). Screens are excluded from app-switcher snapshots if they show phone/email/address (apply a privacy blur on `scenePhase != .active` in `ProfileView`; also used by plan 14).
- **Log out**: `SessionStore.signOut()` clears Keychain token + snapshot, in-memory user, SwiftData caches (plan 01), the image cache, and pending deep links; also unregister the device token if plan 11's `DeviceServicing` exists (best effort, must not block).
- **Delete account**: irreversible; requires a confirmation sheet. On 204 → same wipe as log out. On failure the account and session remain intact. The server must delete the user and anonymize bookings (contract still says "Firestore" — stale; README gap 10). Deleted user's other party still sees anonymized history (e.g. "Deleted user").
- `PATCH /users/me` sends only changed fields; the client never sends `phone`/`email` (identity is verified, immutable in MVP).
- 401 on any call here → global sign-out (plan 01). 403 `profile_incomplete` → router to profile completion.

## IMPLEMENTATION PLAN

### Phase 1: Foundation
`UserRole+Display` helpers, service/fake extensions, notification-preferences UI contract (protocol only).
### Phase 2: Core — ViewModels then views
Profile, EditProfile, Settings (role, payment text, notifications shell), Delete flow.
### Phase 3: Integration
Profile tab in `MainTabView`; role change → tab set; embed plan 04/07/08/10 components; sign-out wipes.
### Phase 4: Testing & Validation

---

## STEP-BY-STEP TASKS

Run from `iOS/`. `TEST=` means `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### CREATE Features/Profile/UserRole+Display.swift
- **IMPLEMENT**: `extension UserRole`: `title` ("I have a spot to rent"/"I need parking"/"Both" — same strings as plan 02), `shortTitle` ("Host"/"Driver"/"Both" for the profile badge and settings toggle labels), `isHost` (`host|both`), `isDriver` (`driver|both`), `showsExploreTab`, `showsListingsTab` (= `isHost`), `showsNoShowCount` (= `isDriver`), `showsPaymentMethodSetting` (= `isHost`).
- **PATTERN**: model-specific extensions live in the model's file or a model-specific file (`iOS/CLAUDE.md` Code Style).
- **GOTCHA**: Tab set: Explore and Bookings are for drivers/both; Listings and Host Inbox for hosts/both. Profile always. Keep this in one place and have `MainTabView` read it (plan 01 says tab visibility depends on `user.role`).
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/RoleTabVisibilityTests`

### UPDATE Services/UserService.swift and FakeUserService
- **IMPLEMENT**: Define `struct UserUpdate: Encodable, Sendable { firstName?, lastName?, address?, role?, paymentMethodText? }` (nil = omit; encoder must not emit nulls) wrapped as `{ "user": … }`; `update(_:) -> User`; `deleteAccount()` with `sendEmpty` (204). Fake records calls and returns queued `Result`s.
- **PATTERN**: plan 01 `UserService` skeleton; plan 02 `ProfileInput`.
- **GOTCHA**: Clearing `payment_method_text` (empty string) vs omitting it are different: send `""` only when the user cleared a previously non-empty value — confirm server semantics (Open Question 4).
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/EditProfileViewModelTests`

### CREATE Features/Profile/ProfileViewModel.swift, ProfileView.swift
- **IMPLEMENT**: `ProfileViewModel` (init: `sessionStore`, `router`) exposes `user: User?` (from `SessionStore.currentUser`), `displayName`, `roleBadge`, `ratingSummary` (`positivePct?`, `count`), `showsNoShowCount`, `showsActiveListings`, `noShowCount`. View sections in order: header (initials avatar — no photo, PRD OQ 1 — plus name, role badge with icon+text); **Rating** via `RatingSummaryView` (plan 04) — empty state "No ratings yet" when `ratingCount == 0` or `ratingPositivePct == nil`; **No-shows** row (drivers/both only; text "N no-shows" with `accessibilityLabel`); **Home address** row + "Edit" → `EditProfileView`; **Active listings** (hosts/both): up to 3 listing rows from plan 07/08's list source with "See all" → Listings tab, empty state "You have no active listings" + CTA "Create a listing" → plan 07 wizard; **Booking history** row → plan 10's list (all users); toolbar gear → `SettingsView`.
- **PATTERN**: `swiftui-development` List/Form with `.scrollContentBackground(.hidden)`, ivory background, `Card`.
- **GOTCHA**: PRD says "total booking count" but `User.rating_count` is the number of **ratings** (Open Question 1) — label it "N ratings" unless the API supplies a booking count. Active listings depends on the missing "my listings" endpoint (README gap 4); render a section-level loading/empty/error state and never block the rest of the screen. Pull-to-refresh reloads listings only.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/ProfileViewModelTests`

### CREATE Features/Profile/EditProfileViewModel.swift, EditProfileView.swift
- **IMPLEMENT**: state `firstName`, `lastName`, `address` (seeded from `currentUser`), `state: SubmitState` (`idle | saving | failed(String)`), `fieldErrors`, computed `hasChanges`, `isValid`, `canSave = hasChanges && isValid && !saving`. `save() async` builds `UserUpdate` from **changed, trimmed** fields only → `userService.update` → `sessionStore.update(user:)` → dismiss. Cancel with unsaved changes → confirmation "Discard changes?". Validation via `ProfileValidation` (names 1–50, address required, same messages as plan 02). 422 `details` mapped to fields; offline → banner with retry; 409/401 per `APIError`.
- **PATTERN**: plan 02 `ProfileCompletionViewModel`.
- **GOTCHA**: If nothing changed, Save is disabled (no empty PATCH). Address is plain text (no Places autocomplete; plan 07 owns that). Keep the sheet `.interactiveDismissDisabled(hasChanges)`.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/EditProfileViewModelTests`

### CREATE Features/Profile/RoleSettingsSection.swift and role-change logic in SettingsViewModel
- **IMPLEMENT**: `SettingsViewModel` (init: `sessionStore`, `userService`, `router`, `notificationService`, `paymentEditor`) with `selectedRole: UserRole`, `roleState`. Role UI reuses `RolePickerView` (plan 02) in a "How you use Spotique" section. `changeRole(to:) async`: optimistic UI is **not** used — show saving spinner, `PATCH { role }`, on success `sessionStore.update(user:)`; `RootView` re-renders tabs from `user.role`; if the selected tab is no longer visible, `router.selectedTab = .profile` (or the first visible tab) with a brief confirmation banner "You're now set up as a driver." On failure the picker reverts to the previous role with an `ErrorBanner`.
  Before applying a **downgrade that removes a capability** (host/both → driver, or driver/both → host) show a confirmation dialog explaining what changes (e.g. "Your listings won't appear on the map while you're a driver only." / "You won't be able to request bookings.") — copy pending Open Question 2.
- **PATTERN**: `SessionStore.update(user:)` is the only mutation point (plan 01 "state transitions only through these methods").
- **GOTCHA**: Do not deactivate/delete listings or cancel bookings client-side on role change — server behavior undefined (Open Question 2). A host with pending or confirmed bookings switching to driver must be handled by the server or blocked (409); map 409 to "Finish or decline your open booking requests first."
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/SettingsViewModelTests -only-testing:SpotiqueTests/RoleTabVisibilityTests`

### CREATE Features/Profile/PaymentMethodEditor.swift
- **IMPLEMENT**: Visible only if `role.showsPaymentMethodSetting`. `TextEditor`/multi-line field bound to `paymentMethodText`, helper "Shown to drivers only after you confirm their booking. Example: Cash or Venmo @janed", `Save` disabled until changed; uses `UserUpdate(paymentMethodText:)`. Character counter with a soft limit (limit TBD — Open Question 3).
- **GOTCHA**: Payments are off-platform (cash/Venmo/Zelle) — never ask for card or bank details; add a validation hint text, not a filter. Value is revealed to drivers by the server only after confirmation; the client just edits it.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/SettingsViewModelTests`

### CREATE Features/Profile/NotificationPreferencesViewModel.swift, NotificationPreferencesView.swift (UI contract only)
- **IMPLEMENT**: Define the UI contract; data/API are owned by plan 11 (no preferences API exists — README gap 9). Protocol (declared here, implemented by plan 11): `NotificationPreferencesServicing { func load() async throws -> [NotificationPreference]; func set(_ type: NotificationType, enabled: Bool) async throws }`, `NotificationType` cases from PRD §4.7 grouped by recipient: `bookingRequestReceived` (host), `bookingConfirmed`, `bookingDeclined` (driver), `ratingWindowOpen` (both), `driverNotArrived` (host, P1), `bookingStartsSoon` (driver, P1), `noShowReported` (driver, P1). View: rows filtered by the user's role, each a `Toggle` with title + explanatory subtitle; a top status row showing OS authorization (`UNAuthorizationStatus`) — if denied, an inline "Notifications are off in iOS Settings" row with a button to `UIApplication.openSettingsURLString`; if `.notDetermined`, a button that asks plan 11 to request permission. Toggle failures revert the switch and show a banner. Until plan 11 ships, inject `FakeNotificationPreferencesService`/an in-memory default-all-on stub and mark the screen behind a `#if`-free feature flag `AppEnvironment.notificationPreferencesAvailable`.
- **GOTCHA**: Turning a type off must not disable the OS permission; required P0 notifications may still be delivered if the API treats them as non-optional — confirm (Open Question 5). Per-toggle in-flight state so rapid toggles don't race; last write wins.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/NotificationPreferencesViewModelTests`

### CREATE Features/Profile/SettingsView.swift (log out + delete account)
- **IMPLEMENT**: Sections: Account (name/email or phone read-only, "Edit profile"), Role, Payment method (hosts), Notifications (navigation row), About (version, Privacy Policy link — URL pending), Log out, Delete account (destructive style, icon + text). **Log out**: `confirmationDialog` "Log out of Spotique?" → `sessionStore.signOut()`; no network dependency (best-effort device unregister only). **Delete account** (`DeleteAccountFlow`): sheet titled "Delete your account?" with plain-language consequences ("Your profile, listings and ratings will be removed. Your past bookings will remain for other users without your name. This can't be undone."), a required confirmation control (type `DELETE` or hold-to-confirm — pick type-to-confirm, Open Question 6), destructive `PrimaryButton`-variant "Delete account" disabled until confirmed, loading state via `LoadingOverlay`; on 204 → `sessionStore.signOut()` (lands on AuthStart); on failure stay signed in with `ErrorBanner` + retry; on 409 (e.g. open bookings) show the server message mapped to a localized string.
- **PATTERN**: `swiftui-development` destructive actions; Apple account-deletion guidance.
- **GOTCHA**: Two-step confirmation only for delete; log out is single confirm. VoiceOver: destructive rows use `.accessibilityHint("Permanently deletes your account")`. Ensure deleting never leaves the token in Keychain even if the response is lost: on network error do **not** sign out (account may still exist); provide retry.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/DeleteAccountTests`

### UPDATE App/RootView.swift (Profile tab and role-driven tabs)
- **IMPLEMENT**: Replace the Profile placeholder with `NavigationStack { ProfileView }`; `MainTabView` builds tabs from `user.role` helpers; handle the "selected tab disappeared" case via `.onChange(of: user.role)`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### UPDATE Localizable.xcstrings
- **IMPLEMENT**: All strings above incl. dialog copy, VoiceOver labels/hints, role toasts. Use pluralized keys for "N ratings", "N no-shows".
- **VALIDATE**: build; review catalog for missing/stale entries.

### CREATE ProfileSettingsUITests
- **IMPLEMENT**: With fake environment: switch role driver → both shows Listings tab; log out returns to auth; delete flow requires confirmation and returns to auth.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueUITests/ProfileSettingsUITests`

---

## TESTING STRATEGY

### Unit Tests
- **ProfileViewModelTests**: derived flags per role (no-show count only driver/both; active listings only host/both); rating empty state (`ratingCount == 0`, `ratingPositivePct == nil`); display name; reacts when `SessionStore.currentUser` changes.
- **EditProfileViewModelTests**: seeded values; `hasChanges` false until edit; whitespace trimming; only changed fields in `UserUpdate` (assert encoded JSON has no nulls/unchanged keys); 50/51-char names; empty address; 422 field mapping; offline → retry keeps edits; success updates SessionStore; cancel-with-changes prompt state.
- **SettingsViewModelTests**: role change success updates `SessionStore.user.role` and adjusts `router.selectedTab` when the current tab is removed; failure reverts picker; downgrade confirmation state machine; payment text save/clear semantics; role list filtering.
- **RoleTabVisibilityTests**: table of `UserRole -> visible tabs`.
- **NotificationPreferencesViewModelTests**: rows by role; toggle success/failure revert; rapid toggles last-write-wins; OS-denied state; service unavailable state.
- **DeleteAccountTests**: confirm gate (typed text case-insensitivity decision); 204 → `signOut` called once and token cleared; network error → **no** sign-out and retry available; 401 → global sign-out; double-tap sends one request; log out clears token/snapshot without network.

### Integration / UI Tests
`ProfileSettingsUITests` with fake environment; no live network.

### Edge Cases
Role change while on a tab that disappears; role change mid-request when app backgrounds; profile edit racing a 401; empty ratings; very long names/addresses (truncate with `lineLimit` + accessibility full text); Dynamic Type XXL in settings rows; VoiceOver rotor headings per section; user with `phone` only vs `email` only (show whichever exists); locale/plurals; delete tapped offline; toggles while OS permission denied; iPad/landscape not in MVP scope.

## VALIDATION COMMANDS (from `iOS/`)

### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests`
### Level 3: Integration Tests
`… test -only-testing:SpotiqueUITests/ProfileSettingsUITests`
### Level 4: Manual Validation
Sign in as driver / host / both accounts; edit name+address (verify Keychain snapshot updated on relaunch); toggle roles and watch tabs; log out then relaunch (must land on sign-in); delete a throwaway account against a local API; VoiceOver + XXL pass; deny OS notifications and check the settings row.

## OPEN QUESTIONS

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | PRD "total booking count" vs API `rating_count` (ratings, not bookings). Add a booking count to the user object or relabel? | Discovered | Assumed relabel "N ratings" |
| 2 | Role change semantics: what happens to active listings, pending/confirmed bookings when a host goes driver-only (or vice versa)? Server rules and copy needed. | Discovered | Pending |
| 3 | Length limit and format for `payment_method_text`. | Discovered | Pending |
| 4 | `PATCH /users/me` not implemented in Rails; empty-string vs omit semantics for clearing `payment_method_text`. | Discovered (Rails routes) | Pending |
| 5 | Notification preferences API (per-type toggles); are P0 notifications opt-out-able? | README gap 9 / PRD §4.8 | Pending — plan 11 |
| 6 | Delete confirmation pattern (type-to-confirm vs hold vs simple alert). | Discovered | Assumed type-to-confirm |
| 7 | Delete-account semantics: contract text still says "Firestore"; confirm REST semantics (hard delete user, anonymize bookings/ratings). Can a user with active/confirmed bookings delete? | README gap 10 | Pending |
| 8 | "My listings" endpoint for the Active listings section. | README gap 4 | Pending |
| 9 | Host profile photo (avatar) in profile? | PRD §8 #1 | Assumed no; initials avatar |
| 10 | Should users be able to change phone/email? (Identity is one verified medium in MVP.) | Spec OQ 1 | Assumed no |
| 11 | Privacy Policy / Terms URLs and support contact for Settings > About. | Discovered | Pending |
| 12 | Can no-show count be shown to the user themself (they see own count; others via plan 12's public stats)? | PRD §4.8 | Assumed yes |

## ACCEPTANCE CRITERIA

- [ ] Profile shows first/last name, home address, rating summary (positive % + count), role, booking history entry for all users
- [ ] No-show count visible to drivers/both only; Active listings section visible to hosts/both only
- [ ] Name (1–50) and address edits validate identically to plan 02, send only changed fields, and update the session immediately
- [ ] Role toggle (Host / Driver / Both) persists via `PATCH /users/me` and updates visible tabs immediately without relaunch; selected-tab fallback works
- [ ] Payment method text editable by hosts; never solicits card/bank details
- [ ] Notification preferences UI lists types per role with OS-permission status; wired to plan 11's protocol
- [ ] Log out clears token, snapshot, caches and returns to sign-in without a network call
- [ ] Delete account requires confirmation, calls `DELETE /users/me`, signs out on 204, and does not sign out on failure
- [ ] Accessibility: labels/hints, 44pt targets, Dynamic Type XXL, no color-only state; all strings in the String Catalog
- [ ] All validation commands pass; no regressions; conventions followed
- [ ] Privacy model upheld (only the user's own data shown; nothing hidden is fetched)
- [ ] `docs/api-contract.md` updated if endpoints changed (notification prefs, delete semantics)

## COMPLETION CHECKLIST

- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] Acceptance criteria met
- [ ] Open questions 2, 4, 5, 7 raised with the API owner

## NOTES

- Reuse, do not rebuild: `RolePickerView`/`ProfileValidation` (02), `RatingSummaryView` (04), booking history list (10), listing rows (07/08). If a dependency is not merged, render a labeled placeholder behind the same section and note it in the PR.
- Delete account is required by App Store Review 5.1.1(v) because accounts can be created in-app; keep it reachable within Settings, not buried.
- Role-driven tab visibility is centralized in `UserRole+Display`; other plans add their tabs by extending that one place.
- Guideline: profile edits never touch listing addresses; the two address concepts (home address vs spot address) must be labeled differently in UI copy ("Home address").
