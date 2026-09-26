---
name: tech-spec
description: Generate a structured tech spec from a PRD feature for the build skill.
argument-hint: "[prd-feature]"
---

# Skill: Tech Spec

Generate a structured tech spec from a PRD feature. The spec is written to `docs/specs/<feature-slug>.md` and serves as the input for the `build` skill.

## Before You Start

1. Read `docs/prd-v1.md` — identify the section for the requested feature.
2. Read `docs/api-contract.md` — identify relevant endpoints.
3. Read `CLAUDE.md` for project context.
4. Read `iOS/CLAUDE.md` and `Android/CLAUDE.md` for platform architecture.
5. Read existing specs in `docs/specs/` to avoid duplicating work.

## Input

The user specifies which PRD feature to spec, e.g.:

- "P0 — Request Booking" (§4.4)
- "P0 — Booking Inbox" (§4.3)
- "P1 — Post-Booking Rating" (§4.6)

## Process

1. **Extract PRD requirements** — Read the relevant PRD section. Copy acceptance criteria verbatim.
2. **Map to API contract** — Identify which endpoints this feature uses. Note any gaps where the contract is missing or incomplete.
3. **Design data models** — Define Firestore document structure and/or Postgres tables. Reference existing models from the API contract. Only define new models if needed.
4. **Specify platform UI** — For each platform (iOS, Android), define the screens, ViewModels, navigation, and state transitions.
5. **Identify edge cases** — Derive from acceptance criteria: conflicts, offline behavior, validation failures, boundary conditions.
6. **Flag open questions** — Check PRD §8 for relevant open questions. Add any new questions discovered during spec writing. These block the build skill.
7. **Write the spec** — Output to `docs/specs/<feature-slug>.md` using the template below.

## Output Template

Write the spec file with this exact structure:

```markdown
# Tech Spec: <Feature Name>

**PRD Reference:** §X.Y — <Section Title>
**Priority:** P0 | P1 | P2
**Status:** Draft | Ready | Building | Done

---

## Overview

2-3 sentences: what this feature does and why it matters.

## PRD Requirements

Copy the acceptance criteria verbatim from the PRD section. Use a blockquote:

> - Acceptance criterion 1
> - Acceptance criterion 2
> - ...

## Data Models

### Firestore / Postgres

For each model involved:

- **Collection/Table name**
- Fields: name, type, constraints, indexes
- Associations / references
- New vs. existing (reference API contract section if existing)

## API Endpoints

For each endpoint this feature touches:

### `METHOD /path`

- **Contract reference:** `docs/api-contract.md` § section (if existing)
- **New or existing:** Existing | New | Modified
- **Request shape:** (if new or modified)
- **Response shape:** (if new or modified)
- **Validations:** list
- **Side effects:** push notifications, status transitions, etc.

## Platform UI

### iOS

For each screen:

- **View:** SwiftUI view name and location
- **ViewModel:** class name, observable state properties, actions
- **Navigation:** how the user reaches this screen, where they go next
- **State transitions:** loading → loaded → error, user interaction flows
- **Error states:** what the user sees on failure

### Android

For each screen:

- **Composable:** function name and package
- **ViewModel:** class name, StateFlow properties, actions
- **Navigation:** how the user reaches this screen, where they go next
- **State transitions:** loading → loaded → error, user interaction flows
- **Error states:** what the user sees on failure

## Privacy & Security

List which rules from PRD §7.2 apply to this feature:

- Address redaction rules
- Phone number visibility rules
- Auth requirements
- Data access restrictions

## Push Notifications

List notification triggers from PRD §4.7 that this feature requires:

| Trigger | Recipient | Message template |
|---------|-----------|-----------------|
| ... | ... | ... |

## Edge Cases

Derived from acceptance criteria and real-world scenarios:

- Conflict handling
- Offline behavior
- Validation boundary conditions
- Race conditions
- Device/platform-specific concerns

## Open Questions

> **These must be resolved before the `build` skill runs.**

| # | Question | Source | Decision |
|---|----------|--------|----------|
| 1 | ... | PRD §8 / Discovered | Pending / Resolved: ... |

## API Contract Changes

If this spec requires changes to `docs/api-contract.md`, list them explicitly:

- **Endpoint:** `METHOD /path`
- **Change:** description of what needs to be added or modified
- **Reason:** why the current contract is insufficient

If no changes are needed, state: "No changes required."
```

## Guidelines

- **Be precise.** Field names must match the API contract exactly. If you introduce new fields, flag them in "API Contract Changes."
- **Be complete.** Every screen the user touches should be specified. Every state (loading, error, empty, success) should be described.
- **Be honest about gaps.** If the PRD is ambiguous or the API contract is missing something, put it in "Open Questions" — don't guess.
- **Reference, don't duplicate.** If the API contract already defines a response shape, reference it by section rather than copying it.
- **One feature per spec.** Don't combine multiple PRD features into one spec. If features are tightly coupled, spec them separately and note the dependency.
