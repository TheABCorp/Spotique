# Feature: iOS Auth & Onboarding (Send Code, Verify, Complete Profile, Session Gating)

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities, and import from the right files. Types named here (`APIClient`, `SessionStore`, `AuthServicing`, `AppEnvironment`, design-system components) are **defined in [01-foundation](01-foundation.md)** — import them, do not redefine.

**Source:** `docs/prd-v1.md` §4.1 (P0 User Registration & Verification), §6.1/§6.2 first steps, §7.2/§7.3; `docs/specs/user-registration.md` (iOS section); `docs/api-contract.md` § Authentication; real Rails code in `Api/app/controllers/api/v1/auth/`, `Api/app/services/`, `Api/test/integration/api/v1/auth/`.

## Feature Description

The entry point for every user. A three-screen flow: **AuthStartView** (choose phone or email, send a 6-digit code) → **CodeVerificationView** (enter code, resend after 60 s) → **ProfileCompletionView** (new users only: first name, last name, home address, role). It replaces plan 01's `AuthFlowPlaceholder` and `.needsProfile` placeholder, implements the live behavior of `AuthServicing`, and drives every `SessionStore` transition out of `.signedOut`/`.needsProfile`.

## User Story

As a new or returning host or driver, I want to verify my phone number or email and (if new) tell Spotique who I am and how I will use it, so that I can access the app with a verified identity.

## Problem Statement

No auth UI exists. Without it no other screen is reachable (PRD: unauthenticated users see nothing beyond the auth flow), and the Rails API returns 401/403 for every other endpoint.

## Solution Statement

Three `@Observable @MainActor` ViewModels, each with a single `State`-style surface, talking only to `AuthServicing` and `SessionStore`. Navigation is a `NavigationStack` owned by an `AuthFlowView` (the signed-out root); the verify step's result decides the next destination via `SessionStore` (`signIn` vs `signInNeedingProfile`), so `RootView` (plan 01) performs the switch to the main app or to `ProfileCompletionView` — the flow never pushes into the main app itself. Error text is derived from status code + a small `AuthErrorMapper` because the Rails auth endpoints currently return **no `error.code`** (see Reality vs. Contract).

## Requirements & Acceptance Criteria

**PRD §4.1 (verbatim)**
- Phone verification restricted to US numbers (+1)
- Email verification accepts any valid email address
- User must verify via their chosen medium before proceeding
- Invalid codes show clear error; resend code available after 60 seconds
- First name, last name, and address are required before accessing the app
- Unauthenticated users cannot access any app screen beyond auth flow
- Role selection can be changed later in Settings (plan 13)

**Spec / contract details**
- `POST /auth/send-code` body `{ "phone": "+13475551234" }` or `{ "email": "…" }` (exactly one). 200 → `data { medium, masked, expires_in }` (`expires_in` = 600 s).
- `POST /auth/verify` body `{ phone|email, code }`. 200 → `data { is_new, token, user }` (`user` is `null` when `is_new`). 401 invalid/expired code; 429 too many attempts.
- `POST /auth/complete-profile` (Bearer token from verify) body `{ "user": { first_name, last_name, address, role } }`; 201 → full `user`; 409 already completed; 422 field errors.
- Client validation: phone starts +1 and 10 digits; email has `@` and a domain; first/last name non-empty, ≤50 chars; address non-empty; a role selected. Primary buttons disabled until valid.
- Copy: role options "I have a spot to rent" (`host`) / "I need parking" (`driver`) / "Both" (`both`). Errors: 429 send → "Too many requests. Please try again later."; offline → "No internet connection. Please try again."; 401 → "Invalid code. Please try again." (clear input); 429 verify → "Too many attempts. Request a new code." (show resend); expired → "Code expired. Please request a new one."; resend label "Resend code (45s)".

## Feature Metadata

**Feature Type**: New Capability
**Estimated Complexity**: Medium
**Platforms**: iOS (Api exists; see gaps)
**Primary Systems Affected**: `Features/Auth/`, `Services/AuthService.swift` (live behavior), `Core/Auth/SessionStore.swift` (snapshot addition), `App/RootView.swift`, `Localizable.xcstrings`
**Dependencies**: Plan 01 only. No Firebase SDK (README gap 1 assumption).

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `iOS/Spotique/Core/Networking/APIClient.swift`, `APIError.swift`, `Endpoint.swift` (plan 01) — `requiresAuth`, error mapping, `onUnauthorized` hook.
- `iOS/Spotique/Core/Auth/SessionStore.swift`, `TokenStore.swift` (plan 01) — `signIn(token:user:)`, `signInNeedingProfile(token:)`, `profileCompleted(user:)`, `signOut()`.
- `iOS/Spotique/Services/AuthService.swift` (plan 01) — `AuthServicing` protocol + `LiveAuthService` skeleton.
- `iOS/Spotique/App/RootView.swift`, `AppEnvironment.swift` — placeholders to replace; where the service is registered.
- `iOS/Spotique/Core/DesignSystem/Components/{PrimaryButton,SecondaryButton,ErrorBanner,LoadingOverlay}.swift`.
- `Api/app/controllers/api/v1/auth/send_code_controller.rb` (lines 4–35: validation order, 400/422/429, response), `verify_controller.rb` (lines 4–36), `complete_profile_controller.rb` (lines 7–24).
- `Api/app/controllers/concerns/{authenticatable,require_complete_profile}.rb` — 401 messages, 403 `profile_incomplete` body (the only auth-related response that carries `error.code`).
- `Api/app/services/jwt_service.rb` — HS256, claims `sub`, `iat` only.
- `Api/app/models/{user,verification_code}.rb` — limits: 10 min expiry, 5 attempts, 3 codes/hour.
- `Api/test/integration/api/v1/auth/*.rb` — behaviors to mirror in fixtures.

### New Files to Create
```
iOS/Spotique/Features/Auth/AuthFlowView.swift                (NavigationStack root; replaces AuthFlowPlaceholder)
iOS/Spotique/Features/Auth/AuthStartView.swift
iOS/Spotique/Features/Auth/AuthStartViewModel.swift
iOS/Spotique/Features/Auth/CodeVerificationView.swift
iOS/Spotique/Features/Auth/CodeVerificationViewModel.swift
iOS/Spotique/Features/Auth/CodeInputField.swift              (6-box input, single hidden TextField, oneTimeCode)
iOS/Spotique/Features/Auth/ProfileCompletionView.swift
iOS/Spotique/Features/Auth/ProfileCompletionViewModel.swift
iOS/Spotique/Features/Auth/RolePickerView.swift              (reused by plan 13)
iOS/Spotique/Features/Auth/ProfileValidation.swift           (name/address rules; reused by plan 13)
iOS/Spotique/Features/Auth/AuthDestination+Validation.swift  (phone/email normalization + validation)
iOS/Spotique/Features/Auth/AuthErrorMapper.swift             (APIError + context -> user string)
iOS/Spotique/Features/Auth/ResendCountdown.swift             (testable countdown, injected Clock)
iOS/SpotiqueTests/Fakes/FakeAuthService.swift                (extend plan 01's fake)
iOS/SpotiqueTests/Fixtures/{send-code,verify-existing,verify-new,complete-profile,error-*}.json
iOS/SpotiqueTests/{AuthStartViewModelTests,CodeVerificationViewModelTests,ProfileCompletionViewModelTests,AuthErrorMapperTests,ResendCountdownTests,AuthServiceTests,SessionRestoreTests}.swift
iOS/SpotiqueUITests/AuthFlowUITests.swift
```

### Documentation — READ BEFORE IMPLEMENTING
- `docs/api-contract.md` § Authentication, § Error Format, § Enums (`user.role`).
- `docs/specs/user-registration.md` § Platform UI → iOS, § Edge Cases.
- `docs/prd-v1.md` §4.1, §7.2, §7.3, §8.
- Apple: [Enabling password/one-time-code AutoFill](https://developer.apple.com/documentation/security/password_autofill/enabling_password_autofill_on_a_text_input_view) (`.textContentType(.oneTimeCode)`), [`Clock` / `ContinuousClock`](https://developer.apple.com/documentation/swift/clock).

### Skills to Apply
- `mvvm-architecture` (ViewModel/service DI, navigation), `swiftui-development` (forms, focus, accessibility, previews), `ios-api-client` (error mapping, public endpoints), `spotique-brand-ui` (navy primary, ivory background; gold never as accent), `ios-security-review` (Keychain, no code/phone in logs), `swift-concurrency-6-2` (default MainActor; `nonisolated` for pure validators).

### Patterns to Follow
- ViewModel: `@Observable @MainActor final class`, protocol deps via `init` (plan 01 "Patterns to Follow"). Prefer a `State` enum for the submit lifecycle (`idle | submitting | failed(String)`); field values stay plain properties.
- Service: `struct LiveAuthService: AuthServicing` builds `Endpoint`s; public endpoints set `requiresAuth: false`.
- Logging: `Log.auth` only, lifecycle events without values (e.g. "send-code failed status=429"). Never log phone, email, code, masked value, token, or address.
- Tests: Swift Testing, `FakeAuthService` returning queued `Result`s, injected `Clock`.

---

## Reality vs. Contract (found in Rails code — plan for the real behavior)

| # | Contract / spec says | Rails does today | iOS handling |
|---|----------------------|------------------|--------------|
| 1 | Errors carry `{code, message, details}` | Auth endpoints return `{error:{message}}` only (no `code`); complete-profile 422 has `details`. Only 403 `profile_incomplete` has a `code`. | Map by HTTP status + context (endpoint), not `error.code`. Display client-owned localized strings; use the server message only as a debug log. |
| 2 | Invalid vs expired code both "401" | 401 "Invalid code. Please try again." vs 401 "No active verification code found. Request a new one." (expired / superseded / already used / none). 5th wrong attempt returns **429**, not 401. | Two 401 cases are indistinguishable without matching message text. Plan: treat message prefix `"No active verification code"` as expired (isolated in `AuthErrorMapper`, one test, flagged fragile) and ask API to add `error.code` `invalid_code` / `code_expired` / `too_many_attempts` (Open Question 1). |
| 3 | verify response includes top-level `data.id` | Rails omits `id`; returns `is_new, token, user`. | `VerifyResult` decoder ignores `id` (use `user.id`). |
| 4 | Existing-user response `user` includes `address` | `users` table has no `address` column; `User#profile_complete?` requires an `addresses` row, and `complete_profile_controller` assigns `address` on `User`. The address-extraction commit (`cb8e3cc`) appears not to be wired into these controllers. | Blocker to confirm with API owner (Open Question 2). iOS treats `address` as `String?` in responses; profile completion must not proceed to `.signedIn` until a 201 is received. |
| 5 | `POST /auth/verify` creates nothing | Rails **creates a blank user** (`User.create!`) on first successful verify. A verified-but-unregistered user therefore exists server-side; abandoning the flow leaves it. | Persist the "profile pending" state (see Session restore) so relaunch resumes at `ProfileCompletionView` without re-verifying. |
| 6 | JWT lifetime unspecified | Claims `sub`, `iat` — **no `exp`**; secret is `secret_key_base`. | No client logic on token expiry; 401 anywhere → `SessionStore.signOut()` (plan 01). |
| 7 | Rate limit 3 codes/hour | Counts every send-code row in the last hour per phone/email; **resend counts**. Also `verify` locks after 5 attempts per code, and a lockout still requires a new code (which counts against the 3). | Resend button state must handle a 429 from resend: disable and show "Too many requests. Please try again later." A locked-out user with 3 codes used has to wait up to an hour. |
| 8 | Email identity | `email` is `citext` (case-insensitive); masked as `ab***@domain`. | Trim and lowercase email before sending; display `masked` exactly as returned. |
| 9 | 400 vs 422 | Both/neither of phone+email → 400; bad format → 422 `Must be a valid US phone number…`. | Client prevents both (single field at a time); a 400 or 422 from send-code maps to the inline format error (generic fallback string). |

## PRIVACY & SECURITY

- No screen beyond the auth flow is reachable without a valid token **and** a complete profile: `RootView` gating is the single enforcement point (plan 01); auth views never push into main tabs.
- The token is written to Keychain (`TokenStoring`) only after a successful `verify`; it is set on `APIClient` via `SessionStore`, never held in a ViewModel property longer than the hand-off.
- Verification code: not logged, not persisted, cleared from memory/UI on 401/429/dismissal; `.textContentType(.oneTimeCode)` for SMS AutoFill on the code field only; disable autocorrect; no `.oneTimeCode` on phone/name fields.
- Phone/email are the user's own; they appear only on the auth screens (masked after send). Not shown to other users; not logged (`Log.auth` interpolations use `privacy: .private` if any). No analytics SDK (PRD §7.2).
- Home address is the user's private profile data, **not** a listing address; sent only in `complete-profile` over HTTPS, held in the ViewModel until submit, stored only in the session snapshot (Keychain, below) for restore. Not written to SwiftData caches or logs.
- 401 on public endpoints (`send-code`, `verify`) and on `complete-profile` must **not** trigger the global "sign out" handler as if a session expired: public endpoints send no `Authorization` header; `complete-profile` 401 is handled locally (see GOTCHA) then routes to sign-in.
- Server enforces: incomplete profiles get 403 on all endpoints except `complete-profile`; the client mirrors this by routing to profile completion but never relies on it.

## IMPLEMENTATION PLAN

### Phase 1: Foundation — validation, mapping, service
`AuthDestination` normalization/validation, `AuthErrorMapper`, `ResendCountdown`, `LiveAuthService` behavior, fixtures.
### Phase 2: Core — ViewModels and views
`AuthStartViewModel`, `CodeVerificationViewModel`, `ProfileCompletionViewModel`, then the three views plus `CodeInputField`, `RolePickerView`.
### Phase 3: Integration — session and root wiring
`AuthFlowView` in `RootView` for `.signedOut`; `ProfileCompletionView` for `.needsProfile`; session snapshot/restore for pending profile; String Catalog; remove placeholders.
### Phase 4: Testing & Validation
Unit, decode, UI test; manual pass with VoiceOver and XXL text.

---

## STEP-BY-STEP TASKS

Run from `iOS/`. `TEST=` shorthand below means `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test`.

### CREATE Features/Auth/AuthDestination+Validation.swift
- **IMPLEMENT**: `nonisolated enum AuthMedium { phone, email }`; `nonisolated enum AuthDestination: Sendable, Equatable { case phone(String), email(String) }` (plan 01 declares the type; add here `static func makePhone(fromInput:) -> AuthDestination?` and `makeEmail(fromInput:)`). Phone: strip everything but digits from user input, drop a leading `1` only if 11 digits, require exactly 10 digits, output `+1XXXXXXXXXX` (matches Rails `\A\+1\d{10}\z`). Email: trim whitespace, lowercase, require `local@domain.tld` (single `@`, non-empty local, domain contains a `.`); server is authoritative via `URI::MailTo::EMAIL_REGEXP`. Provide `requestBody` `["phone": …]` or `["email": …]`.
- **PATTERN**: `docs/specs/user-registration.md` client-side validation; `send_code_controller.rb` lines 40–50.
- **GOTCHA**: Types default to MainActor; mark `nonisolated`. Phone field displays a formatted `(347) 555-1234` mask but VM stores raw digits. Never accept `+44…` — the +1 prefix is a fixed label, not editable.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/AuthStartViewModelTests`

### CREATE Features/Auth/AuthErrorMapper.swift
- **IMPLEMENT**: `enum AuthContext { sendCode, resendCode, verify, completeProfile }`; `func message(for error: APIError, context: AuthContext) -> AuthFailure` returning `AuthFailure { text: String, kind: .inline | .banner | .expiredCode | .locked | .rateLimited | .offline | .conflictAlreadyCompleted | .fieldErrors([String:String]) }`. Mapping: `offline`/timeout → "No internet connection. Please try again."; send/resend `rateLimited` → "Too many requests. Please try again later."; verify `unauthorized` + expired-marker → "Code expired. Please request a new one." (`.expiredCode`, enables resend); verify `unauthorized` otherwise → "Invalid code. Please try again."; verify `rateLimited` → "Too many attempts. Request a new code." (`.locked`); send `validation`/bad request → format error; completeProfile `validation(fields:)` → per-field strings; 409 → `.conflictAlreadyCompleted`; `server`/`unknown` → "Something went wrong. Please try again."
- **PATTERN**: `APIError` cases in plan 01; `iOS ios-api-client` error mapping.
- **GOTCHA**: Expired-marker detection reads the raw server message, so `APIError.unauthorized` must carry the server `message` (ask plan 01 to keep `message` on `.unauthorized`/`.validation`; see NOTES). Isolate in one function so a future `error.code` replaces it in one place.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/AuthErrorMapperTests`

### CREATE Features/Auth/ResendCountdown.swift
- **IMPLEMENT**: `@Observable @MainActor final class ResendCountdown` with `remaining: Int`, `canResend: Bool` (`remaining == 0 && !isLocked`), `start(seconds: Int = 60)`, `cancel()`. Ticks each second using an injected `any Clock<Duration>`; uses a stored `Task` cancelled on `deinit`/`cancel()`.
- **GOTCHA**: Tests must not sleep — inject a controllable clock (e.g. a manual `Clock` test double advancing on demand). Pause/resume when app backgrounds is unnecessary if computed from an end `Date` — prefer storing `endsAt: Date` and deriving `remaining` from `now` each tick so backgrounding does not stall it.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/ResendCountdownTests`

### UPDATE Services/AuthService.swift (live behavior)
- **IMPLEMENT**: `sendCode(_:) -> SendCodeResult { medium, masked, expiresIn }`; `verify(_:code:) -> VerifyResult` as `enum { case existing(token: String, user: User), newUser(token: String) }` (`is_new` + `token` + optional `user`; invariant: `is_new == false` requires non-nil `user`, else throw `.decoding`); `completeProfile(_ input: ProfileInput, token:) -> User` where `ProfileInput { firstName, lastName, address, role }` encodes to `{ "user": { first_name, last_name, address, role } }` (encoder `.convertToSnakeCase`). Endpoints: `POST /auth/send-code` and `/auth/verify` with `requiresAuth: false`; `/auth/complete-profile` with `requiresAuth: true`.
- **PATTERN**: plan 01 `Services/AuthService.swift`; Rails controllers above.
- **GOTCHA**: The token exists only in `SessionStore`/Keychain by the time `complete-profile` is called: `CodeVerificationViewModel` must call `sessionStore.signInNeedingProfile(token:)` (persists token, sets the client token provider) **before** navigation, so `APIClient` attaches it. Do not pass the token by parameter if the `APIClient` already reads it from `TokenStoring` — drop the `token:` parameter in that case. 401 from public endpoints must not invoke `onUnauthorized` (guard on `requiresAuth`).
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/AuthServiceTests` (StubURLProtocol: 200/401/429/422/409, malformed JSON, `is_new:false` with null user → `.decoding`).

### CREATE Features/Auth/AuthStartViewModel.swift
- **IMPLEMENT**: `@Observable @MainActor final class AuthStartViewModel` — state: `selectedMedium: AuthMedium = .phone`, `phoneInput: String`, `emailInput: String`, `state: SubmitState` (`idle | submitting | failed(AuthFailure)`), computed `destination: AuthDestination?`, `isValid`, `canSubmit = isValid && state != .submitting`, `inlineError: String?` (shown only after first blur/submit for format errors). Action `sendCode() async` → on success sets `pendingVerification = PendingVerification(destination:, masked:, expiresIn:)` (drives navigation push to `CodeVerificationView`). Switching medium clears the error, keeps each field's text.
- **PATTERN**: spec "Medium Selection Screen" state list (matches names; `isSubmitting`/`error` folded into `state`).
- **GOTCHA**: Double taps — guard `state != .submitting`. Cancel in-flight task on disappear. Keep `destination` re-derived, not stored, so edits invalidate it.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/AuthStartViewModelTests`

### CREATE Features/Auth/AuthStartView.swift
- **IMPLEMENT**: Ivory background, wordmark, headline "Enter your phone number or email", segmented `Picker` "Phone" / "Email"; phone: fixed "+1" label + number field (`.keyboardType(.numberPad)`, `.textContentType(.telephoneNumber)`); email: `.keyboardType(.emailAddress)`, `.textInputAutocapitalization(.never)`, `.textContentType(.emailAddress)`, `.autocorrectionDisabled()`. `PrimaryButton("Continue")` (loading state, disabled until valid). Link "Already have an account? Sign in" — same flow (sets nothing; scrolls focus to field) per spec. `ErrorBanner` for offline/429/server; inline text for format errors. Footer: "We'll text you a 6-digit code. Message and data rates may apply." Push `CodeVerificationView` via `navigationDestination(item:)`.
- **PATTERN**: `swiftui-development` forms + `@FocusState`; brand tokens only.
- **GOTCHA**: Submit on keyboard `.submitLabel(.continue)`. A segmented control's selection must be announced (`accessibilityValue`). Field labels visible (not placeholder-only). Errors: icon + text, `accessibilityLiveRegion`-style announcement via `AccessibilityNotification.Announcement`.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### CREATE Features/Auth/CodeVerificationViewModel.swift
- **IMPLEMENT**: init(`destination`, `masked`, `authService`, `sessionStore`, `countdown`). State: `code: String` (digits only, max 6; `didSet` filters and auto-submits at 6), `maskedDestination`, `state: VerifyState` (`idle | verifying | failed(AuthFailure)`), `resendState` (`idle | sending | failed`), `countdown: ResendCountdown` (`resendCountdown`, `canResend`), `isLocked: Bool`. Actions: `verifyCode() async`, `resendCode() async`. `verifyCode`: guard `code.count == 6` and not already verifying; on `.existing(token,user)` → `sessionStore.signIn(token:user:)` (RootView switches to main app); on `.newUser(token)` → `sessionStore.signInNeedingProfile(token:)`. On failure: `.invalid` → clear `code`, refocus, message; `.expiredCode` → clear code, `countdown.cancel()` so `canResend` = true immediately; `.locked` → set `isLocked`, clear code, `canResend` true (resend still subject to send-code 429). `resendCode`: calls `sendCode`, replaces `maskedDestination`, clears code and error, restarts countdown at 60; on 429 → disable resend and show rate-limit text (`isResendBlocked = true`, no timer).
- **PATTERN**: spec "Code Verification Screen" (spec's `verificationResult` is replaced by direct SessionStore calls).
- **GOTCHA**: Countdown starts at 60 when the screen appears (send-code just succeeded); the server allows resend immediately, 60 s is a client UX rule from PRD. Ignore duplicate auto-submits (paste of 6 digits). Do not clear `code` while `verifying` (avoids flicker). Cancelling the view cancels tasks.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/CodeVerificationViewModelTests`

### CREATE Features/Auth/CodeInputField.swift, CodeVerificationView.swift
- **IMPLEMENT**: `CodeInputField(text: Binding<String>, hasError: Bool)` — 6 visual boxes over one hidden `TextField` (`.keyboardType(.numberPad)`, `.textContentType(.oneTimeCode)`); the whole control is one accessibility element (label "6-digit verification code", value "3 of 6 digits entered", never reads digits aloud when secure-entry is unwarranted — codes are not secrets on-screen, so read them). Error state shows red border **plus** icon and text. View: instruction "Enter the 6-digit code sent to `masked`", `PrimaryButton("Verify")` (also auto-submits), `SecondaryButton` "Resend code (45s)" → "Resend code" when `canResend`; "Use a different number/email" back action. Show `LoadingOverlay` only while verifying.
- **GOTCHA**: Box row must not truncate at XXL Dynamic Type — use `ViewThatFits` (wrap to 2×3 grid at accessibility sizes). Countdown label updates should not spam VoiceOver: announce once at start and at "Resend available".
- **VALIDATE**: build; previews for idle, error, XXL, dark.

### CREATE Features/Auth/ProfileValidation.swift, RolePickerView.swift
- **IMPLEMENT**: `nonisolated enum ProfileValidation` with `validateName(_:) -> String?` (trim; empty → "Enter your first name"/"…last name"; >50 → "Must be 50 characters or fewer"), `validateAddress(_:) -> String?` (trim; empty → "Enter your home address"), reusable by plan 13. `RolePickerView(selection: Binding<UserRole?>)` — three large selectable rows (radio semantics): "I have a spot to rent" → `.host`, "I need parking" → `.driver`, "Both" → `.both`; selected state = filled radio icon + bold + accessibility trait `.isSelected` (not color alone); ≥44pt rows; grouped as `accessibilityElement(children: .contain)` with label "How will you use Spotique?".
- **GOTCHA**: Count characters with `String.count` (grapheme), matching Rails `length: 1..50` closely enough; trim before counting and before send.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/ProfileCompletionViewModelTests`

### CREATE Features/Auth/ProfileCompletionViewModel.swift, ProfileCompletionView.swift
- **IMPLEMENT**: state `firstName`, `lastName`, `address`, `selectedRole: UserRole?` (no default — user must choose), `state: SubmitState`, `fieldErrors: [Field: String]`, computed `isValid`, `canSubmit`. `completeProfile() async` → `authService.completeProfile(...)`; on success `sessionStore.profileCompleted(user:)` (RootView → main app; initial tab by role: drivers → Explore, hosts → Listings with a "Create your first listing" CTA per §6.1 — via `AppRouter.selectedTab` set by RootView/plan 07, this plan only sets `router.selectedTab` from `user.role`). Errors: 422 `details` keys `first_name|last_name|address|role` → `fieldErrors`; network → alert with Retry; 409 → `.conflictAlreadyCompleted`; 401 → sign out and return to `AuthStartView` with banner "Your session expired. Please verify again."
  View: `Form`-free `ScrollView` of labeled fields (first name `.givenName`, last name `.familyName`, address `.fullStreetAddress` single-line text field with `.textContentType(.fullStreetAddress)`, plain text — no autocomplete; plan 07 owns Places), `RolePickerView`, `PrimaryButton("Complete Registration")`. Helper text under address: "Your home address stays private." (only true if API never exposes it to others — confirm, Open Question 5). No back button to verification (token already issued); provide "Sign out" toolbar item → `sessionStore.signOut()`.
- **PATTERN**: spec "Profile Completion Screen".
- **GOTCHA**: `.needsProfile` can be entered from cold start, so the view must work with no prior navigation. Disable interactive dismissal. Keyboard: `.submitLabel(.next)` chain across fields, `.done` on address.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/ProfileCompletionViewModelTests`

### CREATE Features/Auth/AuthFlowView.swift and UPDATE App/RootView.swift, AppEnvironment.swift
- **IMPLEMENT**: `AuthFlowView` = `NavigationStack { AuthStartView }` creating ViewModels from `AppEnvironment`. In `RootView`: `.signedOut` → `AuthFlowView`; `.needsProfile` → `ProfileCompletionView`; delete `AuthFlowPlaceholder`. Animate transitions with `.transition(.opacity)` (respect Reduce Motion).
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`

### UPDATE Core/Auth/SessionStore.swift (session restore for pending profile)
- **IMPLEMENT**: Persist a minimal `SessionSnapshot { userID?, profileComplete: Bool, user: User? }` **in the Keychain** (same accessibility as the token; it contains home address). `signInNeedingProfile` writes `profileComplete=false`; `signIn`/`profileCompleted` write the user. `restore()`: no token → `.signedOut`; token + snapshot(profileComplete=false) → `.needsProfile`; token + snapshot(user) → `.signedIn(user)`; token + no snapshot → `.signedOut` and clear token (cannot know state; avoid guessing). `signOut()` deletes token + snapshot.
- **GOTCHA**: Plan 01 leaves `GET /users/me` as an open gap; the Rails API only implements the three auth routes. Once `GET /users/me` exists, `restore()` should call it: 403 `profile_incomplete` → `.needsProfile`, 401 → `.signedOut`, 200 → update user. Keep the snapshot only as the offline/instant path.
- **VALIDATE**: `TEST -only-testing:SpotiqueTests/SessionRestoreTests`

### UPDATE Localizable.xcstrings
- **IMPLEMENT**: Add every string in this plan (screen titles, labels, all error messages listed under Requirements, VoiceOver labels). Use `String(localized:)` for VM-produced strings; interpolation for countdown via a plural-safe key "Resend code (%lld s)".
- **VALIDATE**: build; grep for hardcoded literals: `grep -rn 'Text("' iOS/Spotique/Features/Auth | grep -v 'LocalizedStringKey'` reviewed manually.

### CREATE SpotiqueTests fakes, fixtures, and UI test
- **IMPLEMENT**: Extend `FakeAuthService` with queued results and call recording (destinations, codes); fixtures copied from the contract **and from real Rails behavior** (no `data.id`, message-only errors, `is_new:true, user:null`). `AuthFlowUITests`: launch with a `-UITestFakeAuth` launch argument that swaps `AppEnvironment` for a fake; assert unauthenticated launch shows AuthStart, entering a valid phone enables Continue, code "123456" with new user reaches ProfileCompletion.
- **VALIDATE**: `xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueUITests/AuthFlowUITests`

---

## TESTING STRATEGY

### Unit Tests (Swift Testing, `@MainActor` where the VM is)
- **AuthStartViewModelTests**: phone normalization table (`3475551234`, `(347) 555-1234`, `1-347-555-1234`, `+13475551234` → `+13475551234`; 9 digits, 11 non-1-leading digits, letters → invalid); email trim/lowercase/invalid (`a@b`, `@x.com`, `a b@c.com`); Continue disabled until valid; medium switch preserves fields and clears error; success sets `pendingVerification`; 429 → rate-limit copy; offline copy; double-tap sends one request.
- **CodeVerificationViewModelTests**: state machine idle → verifying → (success existing → `signIn` called with user; success new → `signInNeedingProfile`); invalid 401 clears code and shows invalid copy; expired 401 → expired copy and `canResend`; 429 → locked copy, resend enabled; auto-submit exactly once at 6 digits; non-digits stripped; paste of 8 digits truncated to 6; resend restarts countdown at 60 and resets error; resend 429 → resend blocked; task cancelled on deinit.
- **ResendCountdownTests**: starts 60, decrements per tick, `canResend` at 0, restart, cancel; uses manual clock; no sleeping.
- **ProfileCompletionViewModelTests**: validation rules (empty, whitespace-only, 50 vs 51 chars, emoji names, empty address, no role); button enabling; 422 details map to fields; 409 path; 401 → sign out; success → `profileCompleted` and correct initial tab by role; input trimmed before send.
- **AuthErrorMapperTests**: every `(APIError, AuthContext)` pair including expired-marker.
- **AuthServiceTests**: request bodies (`phone` xor `email`), `requiresAuth` flags, 401 on public endpoints does **not** call `onUnauthorized`, decoding `is_new` true/false, missing token → `.decoding`.
- **SessionRestoreTests**: snapshot matrix above; sign-out clears token and snapshot.

### Integration / UI Tests
`AuthFlowUITests` with fake environment (no live network, per `iOS/CLAUDE.md`). Optional local integration against `rails s` with SMS logged (`SmsService` logs the code when Twilio is unset) — manual only.

### Edge Cases
Send-code succeeds but user backgrounds for >10 min → expired copy; airplane mode on verify (code remains valid, retry works); relaunch mid-verification returns to AuthStart (code entry is not resumable — acceptable); force-quit during profile completion resumes at profile (snapshot); user pastes SMS code from keyboard QuickType; email with uppercase; phone pasted with spaces; VoiceOver focus moves to the error after failure; Dynamic Type XXL; Reduce Motion; iPhone SE width; hardware keyboard Return submits.

## VALIDATION COMMANDS (from `iOS/`)

### Level 1: Syntax & Style
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build`
### Level 2: Unit Tests
`xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpotiqueTests`
### Level 3: Integration Tests
`… test -only-testing:SpotiqueUITests/AuthFlowUITests`
### Level 4: Manual Validation
Against local Rails (`Api/`, `bin/rails s`; code is in the Rails log): new phone user end to end; existing user; email path; wrong code x5 → 429; 4th send-code within an hour → 429; expired code (wait 10 min or edit `expires_at`); kill app on profile step and relaunch; VoiceOver full pass; XXL text; dark mode.

## OPEN QUESTIONS

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Add `error.code` (`invalid_code`, `code_expired`, `too_many_attempts`, `rate_limited`) to `/auth/*` so iOS does not parse message text to tell invalid vs expired 401s. | Discovered (Rails) | Pending |
| 2 | Rails `User` has no `address` attribute yet `complete-profile` assigns it and `profile_complete?` needs an `addresses` row — does complete-profile actually work / return `address`? | Discovered (Rails) | Pending — API owner |
| 3 | `GET /users/me` for launch restore; otherwise iOS relies on a Keychain snapshot. | README gap 5 | Pending |
| 4 | Token has no `exp`; refresh strategy? (401 -> re-verify by code.) | README gap 2 | Pending |
| 5 | Is the user's home address ever visible to other users? Copy "Your home address stays private" depends on it. | Discovered | Pending |
| 6 | REST + JWT only, no Firebase Auth SDK. `iOS/CLAUDE.md` and `ios-security-review` still say Firebase phone auth. | README gap 1 | Assumed yes |
| 7 | Host profile photo required at signup? | PRD §8 #1 | Assumed no — not in this flow |
| 8 | Should a user be able to link phone and email (spec OQ 1)? | Spec | Assumed no; one medium per account |
| 9 | Push permission prompt timing — spec says after registration completes, on first entry to main app. Owned by plan 11; this plan only lands the user in main app. | Spec | Deferred to 11 |
| 10 | Apple Sign in / "Sign in with Apple" requirement does not apply (no third-party login), confirm. | Discovered | Pending |
| 11 | Terms of Service / Privacy Policy consent link on AuthStart? Not in PRD; App Store requires a privacy policy URL. | Discovered | Pending |
| 12 | 60 s resend is client-only; the server allows immediate resend up to 3/hour. Keep? | Discovered | Assumed keep (PRD) |

## ACCEPTANCE CRITERIA

- [ ] Unauthenticated launch shows only `AuthStartView`; no other screen reachable
- [ ] Phone path accepts only US numbers, sends `+1XXXXXXXXXX`; email path trims/lowercases and validates format
- [ ] Code screen: 6 digits, auto-submit, invalid/expired/locked errors use the exact copy above, code clears on failure
- [ ] Resend disabled for 60 s with visible "Resend code (Ns)"; 429 on resend disables it with rate-limit copy
- [ ] Existing user lands in main app; new user lands in `ProfileCompletionView`; relaunch mid-profile resumes there without re-verifying
- [ ] Profile requires first name (≤50), last name (≤50), address, role; role labels match PRD; 422 field errors shown per field
- [ ] Token only in Keychain; sign-out clears token and snapshot; no code/phone/email/token/address in logs
- [ ] 401 on public endpoints never triggers global sign-out; 401 on `complete-profile` routes to sign-in with a message
- [ ] VoiceOver labels, 44pt targets, Dynamic Type XXL, no color-only state, Reduce Motion respected; all strings in the String Catalog
- [ ] All validation commands pass; no regressions; conventions followed
- [ ] Privacy model upheld (no early exposure of address/host phone — n/a in this flow beyond own data)
- [ ] `docs/api-contract.md` updated if the API adds error codes or `GET /users/me`

## COMPLETION CHECKLIST

- [ ] All tasks completed in order, each validated
- [ ] Full test suite passes
- [ ] `AuthFlowPlaceholder` and `.needsProfile` placeholder removed
- [ ] Open questions 1–3 raised with the API owner and recorded

## NOTES

- Keep the ViewModels' names and property names from the spec (`selectedMedium`, `phoneNumber`→`phoneInput`, `resendCountdown`, `canResend`, `firstName`…); `isSubmitting`/`isVerifying`/`error` are folded into `state` per the `iOS/CLAUDE.md` "one State enum" rule.
- Plan 01 change needed: `APIError.unauthorized` and `.validation` must retain the server `message` (and 400 must map to `.validation` or `.badRequest`), and `APIClient` must skip `onUnauthorized` for `requiresAuth == false` endpoints and provide a way for one call to opt out (complete-profile).
- `RolePickerView` and `ProfileValidation` are shared with plan 13; do not fork them.
- The blank user created at `verify` means an abandoned signup leaves a phone/email unusable for re-signup until it is completed; sign-in with the same medium simply returns `is_new: true` again (Rails `User.find_by` finds it but `is_new` is `false` with an incomplete user and `user` payload with null fields) — **check**: for an existing-but-incomplete user Rails returns `is_new: false` and a `user` whose `first_name/last_name/role` are null. iOS must treat `is_new == false` with `role == nil` or empty `first_name` as `signInNeedingProfile`. Decode `User` fields as optional in this path (add to `VerifyResult` decode: `existing` requires `user.isProfileComplete`, else `.newUser(token)`). Add a test for this case.
