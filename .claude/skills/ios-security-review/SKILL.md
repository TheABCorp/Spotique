---
name: ios-security-review
description: Review Spotique iOS code and configuration for security and privacy — Keychain, data protection, network/ATS, auth, address/phone privacy rules, logging, and App Store privacy compliance. Defensive review of our own app.
argument-hint: "[files-or-area]"
---

# Skill: iOS Security & Privacy Review (Spotique)

Use to review changes (or the whole app) in `iOS/` for security and privacy issues. This is a defensive code and configuration review of our own app.

## Spotique's Privacy Model (highest priority)

These are product requirements, not nice-to-haves:

- The **full street address** and the **host's phone number** are hidden until a booking is confirmed. Before confirmation the app may only show the approximate location.
- The **driver's phone** is shared with the host at booking creation.
- Users must be **verified** (phone SMS via Firebase Auth) before accessing any screen.

Verify by tracing the data: where is it received, held in state, cached, persisted, logged, put into analytics, or shown in screenshots/app-switcher snapshots? Any path that exposes hidden data before confirmation is a High finding. Also check that the server, not the client, enforces this — the client must never be the only guard (flag contract gaps in `docs/api-contract.md`).

## Checklist

**Secrets & credentials**
- No API keys, tokens, or private keys committed. Google Maps/Places keys are restricted (bundle ID, API scope); `GoogleService-Info.plist` handling follows repo policy.
- Auth tokens and any persisted credentials live in the **Keychain** (appropriate `kSecAttrAccessible`, e.g. `AfterFirstUnlockThisDeviceOnly` or stricter) — never `UserDefaults`, plists, or SwiftData plain fields.

**Data at rest**
- Sensitive files use an appropriate `FileProtectionType`.
- Caches contain only pre-booking-safe data (see privacy model); cache is cleared on sign-out.
- SwiftData/file stores excluded from backup if they hold sensitive data.

**Network**
- HTTPS only; App Transport Security not weakened (`NSAllowsArbitraryLoads` absent, no broad exceptions).
- Certificate pinning is optional at MVP; if added, plan for rotation.
- Auth header attached only to our API host, never to third-party URLs.
- Server errors don't leak internals to the UI.

**Authentication**
- Firebase ID token refreshed properly; 401 handling signs out cleanly.
- Verification-code entry: no code in logs, rate-limited resend UX, no autofill leaking to other fields.
- Sign-out clears tokens, caches, and in-memory user data.

**Logging & telemetry**
- `os.Logger` with `.private` for personal data; no `print` of phones, addresses, tokens, verification codes.
- Analytics/crash events contain no PII.

**Input & UI**
- Validate and sanitize user input (address search, times); handle malformed server data without crashing.
- Sensitive screens (confirmed address/phone) are hidden in the app-switcher snapshot when appropriate.
- Pasteboard not used for sensitive values; `textContentType` set correctly for phone/OTP fields.
- Deep links and push payloads are treated as untrusted input: validate identifiers, and require auth before acting.

**Permissions & App Store privacy**
- Only necessary permissions requested (location "when in use" at most), with clear purpose strings in `Info.plist`.
- `PrivacyInfo.xcprivacy` privacy manifest declares collected data types and required-reason APIs, including those used by Firebase/Maps SDKs.
- App Privacy details in App Store Connect match actual behavior.
- Push registration only after the user has been verified.

**Dependencies**
- Third-party SDKs (Firebase, Google Maps) pinned to known versions and reviewed when updated.

## Output Format

```
### High / Medium / Low
- `path/File.swift:88` — <issue>. <Concrete impact, e.g. "host phone persisted to UserDefaults before confirmation">. <Fix>.
```

Note anything you couldn't verify (e.g. server-side enforcement) as an open question rather than assuming it's fine.
