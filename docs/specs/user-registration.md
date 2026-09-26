# Tech Spec: User Registration & Verification

**PRD Reference:** §4.1 — Authentication & Onboarding
**Priority:** P0
**Status:** Draft

---

## Overview

Users register in two phases. First, **verification**: the user proves ownership of a US phone number or email address by entering a 6-digit code sent to that medium. On successful verification, the server issues an **authentication token**. Second, **profile completion**: the user submits their first name, last name, address, and role — this request (and every request after it) includes the authentication token as a bearer header. Until both phases are complete, the user cannot access any other part of the app. This is the entry point for every user — hosts and drivers alike.

## PRD Requirements

From §4.1 — User Registration & Verification:

> - User chooses to sign up with either a US mobile phone number or an email address
> - App sends a 6-digit verification code to the chosen medium (SMS for phone, email for email)
> - User enters the 6-digit code to verify ownership
> - New users complete a profile form: first name, last name, and home address
> - New users select role: "I have a spot to rent" / "I need parking" / "Both"

> **Acceptance criteria:**
> - Phone verification restricted to US numbers (+1)
> - Email verification accepts any valid email address
> - User must verify via their chosen medium before proceeding
> - Invalid codes show clear error; resend code available after 60 seconds
> - First name, last name, and address are required before accessing the app
> - Unauthenticated users cannot access any app screen beyond auth flow
> - Role selection can be changed later in Settings

## Data Models

### Users (Postgres)

| Field | Type | Constraints |
|-------|------|------------|
| `id` | string (UUID) | PK, generated server-side |
| `phone` | string | Unique, nullable (one of phone/email required) |
| `email` | string | Unique, nullable (one of phone/email required) |
| `first_name` | string | Required, 1–50 characters |
| `last_name` | string | Required, 1–50 characters |
| `address` | string | Required |
| `role` | enum | `host`, `driver`, `both` — required |
| `payment_method_text` | string | Optional, set later |
| `rating_positive_pct` | integer | Nullable, 0–100 |
| `rating_count` | integer | Default: 0 |
| `no_show_count` | integer | Default: 0 |
| `created_at` | datetime | Auto |
| `updated_at` | datetime | Auto |

**Indexes:** Unique on `phone` (where not null), unique on `email` (where not null).

**Constraint:** Check constraint ensuring at least one of `phone` or `email` is not null.

### Verification Codes (Postgres — new)

Stores pending verification codes. Rows are short-lived and cleaned up after verification or expiry.

| Field | Type | Constraints |
|-------|------|------------|
| `id` | bigint | PK |
| `phone` | string | Nullable |
| `email` | string | Nullable |
| `code` | string | 6 digits, hashed |
| `expires_at` | datetime | 10 minutes from creation |
| `attempts` | integer | Default: 0, max 5 before lockout |
| `verified_at` | datetime | Nullable, set on successful verification |
| `created_at` | datetime | Auto |

**Indexes:** Index on `(phone, created_at)`, index on `(email, created_at)`.

**Constraint:** At least one of `phone` or `email` is not null.

## API Endpoints

> **Verification vs. authentication:** Verification is the one-time act of proving ownership of a phone number or email via a 6-digit code. Authentication is the ongoing act of proving identity on every API request via a bearer token. Verification happens once (during registration or sign-in); authentication happens on every subsequent request.
>
> The two public endpoints (`send-code`, `verify`) require no token. Every other endpoint in the app — including `complete-profile` — requires the `Authorization: Bearer <token>` header.

### `POST /auth/send-code`

- **Contract reference:** `docs/api-contract.md` § Authentication
- **New or existing:** New
- **Authentication:** None (public endpoint)
- **Purpose:** Initiate verification by sending a 6-digit code to the user's phone or email.
- **Request shape:**
  ```json
  { "phone": "+13475551234" }
  ```
  Or:
  ```json
  { "email": "jane@example.com" }
  ```
- **Validations:**
  - Exactly one of `phone` or `email` required
  - `phone`: valid US number (+1, 10 digits after country code)
  - `email`: valid email format
  - Rate limit: max 3 codes per phone/email per hour → 429
- **Side effects:**
  - Generates a 6-digit code, stores hashed version in `verification_codes` table
  - Sends SMS (for phone) or email (for email) with the code
  - Expires any outstanding codes for the same phone/email
- **Response (200):**
  ```json
  {
    "data": {
      "medium": "phone",
      "masked": "+1347***1234",
      "expires_in": 600
    }
  }
  ```

### `POST /auth/verify`

- **Contract reference:** `docs/api-contract.md` § Authentication
- **New or existing:** New
- **Authentication:** None (public endpoint)
- **Purpose:** Complete verification by validating the 6-digit code. On success, issues an authentication token that the client must store and send as `Authorization: Bearer <token>` on all subsequent API requests.
- **Request shape:**
  ```json
  { "phone": "+13475551234", "code": "482910" }
  ```
- **Validations:**
  - Code matches the most recent unexpired, unverified code for this phone/email
  - Max 5 attempts per code → 429 with message "Too many attempts. Request a new code."
  - Code not expired (10-minute window)
- **Response:**
  - Existing user: returns `is_new: false` with full user object and authentication token
  - New user: returns `is_new: true` with authentication token, `user: null` — the client must call `POST /auth/complete-profile` before the user can access any other endpoint
  - Invalid code: 401
- **Note:** This is the boundary between verification and authentication. Before this call, the user is proving they own a phone/email. After this call succeeds, the user has an authentication token and is considered signed in.

### `POST /auth/complete-profile`

- **Contract reference:** `docs/api-contract.md` § Authentication
- **New or existing:** New
- **Authentication:** Required — `Authorization: Bearer <token>` (token from `POST /auth/verify`)
- **Purpose:** Finish registration for new users. This is an authenticated endpoint — the token from `POST /auth/verify` must be sent in the `Authorization` header.
- **Request shape:**
  ```json
  {
    "user": {
      "first_name": "Jane",
      "last_name": "Doe",
      "address": "34-15 74th Street, Jackson Heights, NY 11372",
      "role": "host"
    }
  }
  ```
- **Validations:**
  - Valid authentication token required (401 if missing or invalid)
  - Caller must be a new user with no existing profile (409 if profile already exists)
  - `first_name`: required, 1–50 characters
  - `last_name`: required, 1–50 characters
  - `address`: required
  - `role`: required, one of `host`, `driver`, `both`
- **Response (201):** Full user object

## Platform UI

### iOS

#### Medium Selection Screen

- **View:** `AuthStartView`
- **ViewModel:** `AuthStartViewModel`
  - **State:**
    - `selectedMedium: AuthMedium` — enum: `.phone`, `.email`
    - `phoneNumber: String`
    - `email: String`
    - `isSubmitting: Bool`
    - `error: String?`
  - **Actions:**
    - `sendCode()` — calls `POST /auth/send-code`
  - **Client-side validation:**
    - Phone: starts with +1, 10 digits after country code
    - Email: contains `@` and a domain
    - "Continue" button disabled until valid
- **Navigation:** App launch (if not authenticated) → this screen
- **UI elements:**
  - Segmented control or tabs: "Phone" / "Email"
  - Phone: country code (+1 fixed) + phone number field with numeric keyboard
  - Email: email text field with email keyboard
  - "Continue" button
  - Link: "Already have an account? Sign in" (same flow — verification determines new vs. existing)
- **Error states:**
  - 429 rate limit → "Too many requests. Please try again later."
  - Network error → "No internet connection. Please try again."
  - Invalid phone format → inline validation error

#### Code Verification Screen

- **View:** `CodeVerificationView`
- **ViewModel:** `CodeVerificationViewModel`
  - **State:**
    - `code: String` — 6 characters
    - `maskedDestination: String` — from send-code response (e.g. "+1347***1234")
    - `isVerifying: Bool`
    - `error: String?`
    - `resendCountdown: Int` — starts at 60, counts down to 0
    - `canResend: Bool` — true when countdown reaches 0
    - `verificationResult: VerificationResult?` — `.newUser(token)` or `.existingUser(token, user)`
  - **Actions:**
    - `verifyCode()` — calls `POST /auth/verify`. On success, stores the returned authentication token in Keychain and sets it on the API client for all future requests.
    - `resendCode()` — calls `POST /auth/send-code` again, resets countdown
- **Navigation:** From AuthStartView → on success with existing user (token stored, profile complete), navigate to main app. On success with new user (token stored, profile incomplete), navigate to ProfileCompletionView.
- **UI elements:**
  - Instruction text: "Enter the 6-digit code sent to [masked destination]"
  - 6-digit code input (individual digit boxes, auto-advance)
  - "Verify" button (or auto-submit on 6th digit)
  - "Resend code" button with countdown: "Resend code (45s)"
- **Error states:**
  - 401 invalid code → "Invalid code. Please try again." (clear input)
  - 429 too many attempts → "Too many attempts. Request a new code." (show resend button)
  - Code expired → "Code expired. Please request a new one."

#### Profile Completion Screen

- **View:** `ProfileCompletionView`
- **ViewModel:** `ProfileCompletionViewModel`
  - **State:**
    - `firstName: String`
    - `lastName: String`
    - `address: String`
    - `selectedRole: UserRole` — enum: `.host`, `.driver`, `.both`
    - `isSubmitting: Bool`
    - `error: String?`
  - **Actions:**
    - `completeProfile()` — calls `POST /auth/complete-profile` with the authentication token in the `Authorization` header
  - **Client-side validation:**
    - First name: not empty, max 50 chars
    - Last name: not empty, max 50 chars
    - Address: not empty
    - Role: one selected
    - "Complete" button disabled until all valid
- **Navigation:** From CodeVerificationView (new users only) → on success, navigate to main app
- **UI elements:**
  - First name text field
  - Last name text field
  - Address text field (plain text input — no autocomplete needed for user's home address)
  - Role selection: three buttons or radio group — "I have a spot to rent" (host) / "I need parking" (driver) / "Both"
  - "Complete Registration" button
- **Error states:**
  - 422 validation errors → show per-field errors
  - Network error → alert with retry

### Android

#### Medium Selection Screen

- **Composable:** `AuthStartScreen` in `com.spotique.feature.auth`
- **ViewModel:** `AuthStartViewModel`
  - **StateFlow:** `AuthStartUiState`
    - `selectedMedium: AuthMedium` — enum: `PHONE`, `EMAIL`
    - `phoneNumber: String`
    - `email: String`
    - `isSubmitting: Boolean`
    - `error: String?`
  - **Actions:**
    - `selectMedium(medium: AuthMedium)`
    - `updatePhone(phone: String)`
    - `updateEmail(email: String)`
    - `sendCode()`
- **Navigation:** App launch (if not authenticated) → this screen
- **UI elements:** Same as iOS — tabs for Phone/Email, input field, Continue button
- **Error states:** Same as iOS

#### Code Verification Screen

- **Composable:** `CodeVerificationScreen` in `com.spotique.feature.auth`
- **ViewModel:** `CodeVerificationViewModel`
  - **StateFlow:** `CodeVerificationUiState`
    - `code: String`
    - `maskedDestination: String`
    - `isVerifying: Boolean`
    - `error: String?`
    - `resendCountdownSeconds: Int`
    - `canResend: Boolean`
  - **Actions:**
    - `updateCode(code: String)`
    - `verifyCode()` — on success, stores the returned authentication token in EncryptedSharedPreferences and sets it on the Retrofit OkHttp interceptor for all future requests
    - `resendCode()`
- **Navigation:** From AuthStartScreen → on existing user (token stored, profile complete), navigate to main app. On new user (token stored, profile incomplete), navigate to ProfileCompletionScreen.
- **UI elements:** Same as iOS
- **Error states:** Same as iOS

#### Profile Completion Screen

- **Composable:** `ProfileCompletionScreen` in `com.spotique.feature.auth`
- **ViewModel:** `ProfileCompletionViewModel`
  - **StateFlow:** `ProfileCompletionUiState`
    - `firstName: String`
    - `lastName: String`
    - `address: String`
    - `selectedRole: UserRole`
    - `isSubmitting: Boolean`
    - `error: String?`
  - **Actions:**
    - `updateFirstName(name: String)`
    - `updateLastName(name: String)`
    - `updateAddress(address: String)`
    - `selectRole(role: UserRole)`
    - `completeProfile()`
- **Navigation:** From CodeVerificationScreen (new users only) → on success, navigate to main app
- **UI elements:** Same as iOS
- **Error states:** Same as iOS

## Privacy & Security

Per PRD §7.2:

- **Two public endpoints only:** `POST /auth/send-code` and `POST /auth/verify` are the only endpoints that do not require an authentication token. Every other endpoint in the API requires `Authorization: Bearer <token>`.
- **Authentication token lifecycle:** The token is issued by `POST /auth/verify` on successful code verification. The client stores it securely (Keychain on iOS, EncryptedSharedPreferences on Android) and sends it on every subsequent request. If the token is missing or invalid, the API returns 401.
- **Incomplete profiles blocked:** A user who has verified but not yet completed their profile can only call `POST /auth/complete-profile`. All other authenticated endpoints return 403 with `"profile_incomplete"` until the profile is submitted. This prevents a verified-but-unregistered user from browsing listings or creating bookings.
- **Phone/email visibility:** A user's phone number or email is never displayed to other users in the auth flow. It is only shared in the context of bookings (driver phone to host on booking creation, host phone to driver on confirmation).
- **Verification codes:** Codes are hashed before storage. Codes expire after 10 minutes. Max 5 verification attempts per code. Max 3 codes per phone/email per hour.

## Push Notifications

No push notifications are triggered by the registration flow. Push notification permission should be requested after registration is complete (on first entry to the main app).

## Edge Cases

- **Existing user signs in with phone, later tries email (or vice versa):** The system identifies users by their verified phone or email. If a user initially registers with phone and later tries to verify with email, they would be treated as a new user. For MVP, each user has one identity medium. Supporting linking multiple mediums is out of scope.
- **Code expires while user is typing:** If the user submits after 10 minutes, the server returns 401. The client should show "Code expired. Please request a new one." and offer a resend button.
- **Multiple codes requested in quick succession:** Only the most recent code is valid. Older codes for the same phone/email are invalidated when a new one is created.
- **User force-quits app during profile completion:** On next launch, the app finds a valid authentication token in secure storage but no cached user profile. It calls any authenticated endpoint (e.g. `GET /users/me` or equivalent), which returns 403 `"profile_incomplete"`. The app navigates directly to the profile completion screen. The user does not need to re-verify.
- **Rate limiting (3 codes/hour):** After 3 send-code requests, the server returns 429. The client shows "Too many requests. Please try again later." and disables the resend button.
- **5 failed verification attempts:** After 5 wrong codes, the server returns 429. The client must request a new code.
- **Network loss during code submission:** Client shows an offline error. The code remains valid server-side until it expires, so the user can retry when connectivity returns.
- **Very long address input:** No strict max length enforced in MVP. The address field accepts free text. Future iteration may add Google Places Autocomplete for user addresses.

## Open Questions

> **These must be resolved before the `build` skill runs.**

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | Should the app support linking both phone and email to the same account, or is each user tied to one medium? | Discovered | Pending |
| 2 | What SMS provider and email delivery service will be used for sending verification codes? | Discovered | Pending |
| 3 | Should the user's home address use Google Places Autocomplete, or is free text sufficient for MVP? | Discovered | Pending |
| 4 | What token format and signing strategy should the API use (JWT, opaque tokens, etc.)? | Discovered | Pending |

## API Contract Changes

The following endpoints have been added to `docs/api-contract.md` as part of this spec:

- **Endpoint:** `POST /auth/send-code` — New. Sends a 6-digit verification code to a phone or email.
- **Endpoint:** `POST /auth/verify` — Modified. Now supports both phone and email. Returns `is_new` flag and token. Previous version accepted a Firebase ID token directly.
- **Endpoint:** `POST /auth/complete-profile` — New. Completes registration for new users with first name, last name, address, and role.
- **User object shape:** Updated. `display_name` replaced with `first_name`, `last_name`, `address`. Added `email` field. `host_display_name` in listing responses remains as a computed field (server derives from `first_name` + last initial).
