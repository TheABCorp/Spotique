---
name: build
description: Take a completed tech spec and generate code across all platforms (Rails API, iOS, Android).
argument-hint: "[path-to-spec]"
---

# Skill: Build from Tech Spec

Take a completed tech spec and generate code across all platforms. This skill chains the existing platform skills (`rails-api`, `ios-feature`, `android-feature`).

## Before You Start

1. Read the tech spec file (e.g. `docs/specs/booking-request.md`).
2. Read `docs/api-contract.md`.
3. Read `CLAUDE.md`, `Api/CLAUDE.md`, `iOS/CLAUDE.md`, `Android/CLAUDE.md`.

## Input

Path to a completed tech spec file, e.g.:

```
docs/specs/booking-request.md
```

## Pre-flight Checks

Before writing any code, verify:

1. **No unresolved open questions.** Check the spec's "Open Questions" section. Every row must have a decision. If any are "Pending," stop and ask the user to resolve them.
2. **API contract changes listed.** If the spec's "API Contract Changes" section lists modifications, they will be applied in Phase 1. If it says "No changes required," proceed.
3. **Spec status is "Ready."** If the status field says "Draft," stop and ask the user to finalize it.

## Build Phases

Execute these phases in order. Commit after each phase before proceeding.

### Phase 1: API Contract Update

If the spec's "API Contract Changes" section lists modifications:

1. Apply each change to `docs/api-contract.md`.
2. Verify the contract is internally consistent (no conflicting field names, proper HTTP status codes).
3. Commit: `git add docs/api-contract.md && git commit -m "docs: update API contract for <feature>"`

If "No changes required," skip this phase.

### Phase 2: Rails API

Follow the `rails-api` skill (`.claude/skills/rails-api.md`).

1. Read the spec's "Data Models" section. Generate migrations for any new tables or columns.
2. Read the spec's "API Endpoints" section. Implement each endpoint.
3. Implement side effects (push notifications, status transitions) per the spec.
4. Write request specs covering:
   - Happy path
   - Auth failures (missing/invalid token)
   - Validation errors (each validation listed in the spec)
   - Edge cases from the spec's "Edge Cases" section
5. Run tests: `cd Api && bundle exec rspec`
6. Run linter: `cd Api && bin/rubocop`
7. Commit: `git add Api/ && git commit -m "feat(api): implement <feature>"`

### Phase 3: iOS + Android (parallel)

Launch two agents simultaneously using the Task tool:

**iOS agent:**
```
Implement <feature> in iOS/ following:
- Tech spec: docs/specs/<feature-slug>.md (Platform UI → iOS section)
- Skill: .claude/skills/ios-feature.md
- API contract: docs/api-contract.md
- Platform guide: iOS/CLAUDE.md
```

**Android agent:**
```
Implement <feature> in Android/ following:
- Tech spec: docs/specs/<feature-slug>.md (Platform UI → Android section)
- Skill: .claude/skills/android-feature.md
- API contract: docs/api-contract.md
- Platform guide: Android/CLAUDE.md
```

After both agents complete:
- Review their output for consistency with the spec.
- Commit iOS: `git add iOS/ && git commit -m "feat(ios): implement <feature>"`
- Commit Android: `git add Android/ && git commit -m "feat(android): implement <feature>"`

### Phase 4: Cross-Platform Verification

Verify consistency across all platforms before finalizing:

1. **Field name consistency** — All platforms (Rails models, iOS structs, Android data classes) use the same field names as the API contract. Check request/response serialization matches exactly.
2. **Privacy rules enforced** — Address and phone number redaction matches the spec's "Privacy & Security" section. Verify no platform leaks data the spec says should be hidden.
3. **Auth flow consistency** — All platforms send the `Authorization: Bearer <token>` header. Token storage is secure (Keychain on iOS, EncryptedSharedPreferences on Android). Expired tokens produce a 401 that triggers re-auth.
4. **Push notifications wired** — Each trigger in the spec's "Push Notifications" section is implemented server-side and handled client-side on both platforms.
5. **Enum and status values** — Booking/listing status strings, role values, spot types, and rating tags match the API contract's enum table exactly across all platforms.

Report any discrepancies. Fix in the offending platform, re-run its tests, and commit before proceeding.

### Phase 5: Spec Update

Update the tech spec's status field:

```
**Status:** Done
```

Commit: `git add docs/specs/<feature-slug>.md && git commit -m "docs: mark <feature> spec as done"`

## Commit Gates

Each phase must be committed before the next phase begins. This ensures:

- Partial progress is preserved if a later phase fails.
- Code review can happen per-phase if needed.
- Git history shows the build progression clearly.

## Failure Handling

- **Test failures in Phase 2:** Fix the code, re-run tests, then commit. Do not proceed to Phase 3 with failing API tests.
- **Build failures in Phase 3:** Fix per-platform. If the failure is due to a spec ambiguity, stop and ask the user.
- **Integration issues in Phase 4:** Fix the inconsistency in the offending platform. Re-run that platform's tests. Commit the fix.
