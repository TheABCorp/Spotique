---
name: create-prd
description: Create a Spotique Product Requirements Document (new version or new feature area) from the conversation, matching the structure of docs/prd-v1.md so the tech-spec skill can consume it.
argument-hint: "[output-filename]"
---

# Skill: Create PRD

Generate a Product Requirements Document from the current conversation and the existing Spotique docs.

## Output File

Write the PRD to `$ARGUMENTS`. If none is given, default to the next version in `docs/` (e.g. `docs/prd-v2.md` if `docs/prd-v1.md` exists). Never overwrite an existing PRD without the user's confirmation.

## Before You Start

1. Read `CLAUDE.md` for product facts (MVP geography, off-platform payments, verified identity, privacy and trust models).
2. Read `docs/prd-v1.md` — it is the format and terminology reference. Reuse its persona names, feature-ID style, and priorities (P0/P1) so PRDs stay consistent.
3. Read `docs/api-contract.md` to see what already exists, and `docs/specs/` to see what has been specced.
4. Review the whole conversation: explicit requirements, implicit needs, constraints, and decisions already made.

If critical information is missing (who the feature is for, what problem it solves, what's in or out of MVP), ask the user before writing. Otherwise make reasonable assumptions and list them at the end.

## Structure

Follow the section layout of `docs/prd-v1.md`. The `tech-spec` skill reads §4 (feature requirements) and §8 (open questions) directly, so keep those in place and numbered.

1. **Product Overview** — vision, problem statement, solution (2–3 short paragraphs; core value proposition and the goal of this release)
2. **Target Users** — personas (host, driver, or new ones) with context, needs, pain points, and technical comfort
3. **Goals & Success Metrics** — a north-star metric and measurable targets with timeframes
4. **Feature Requirements** — grouped by area (`4.1`, `4.2`, …). Each feature has:
   - a heading `#### P0 — <Feature Name>` (P0 = must-have for the release, P1 = should-have)
   - a user story: "As a [persona], I want [action], so that [benefit]"
   - **acceptance criteria** as a checklist — specific and testable (this is copied verbatim into tech specs)
   - relevant screens/states, validations, and edge cases where known
5. **Out of Scope** — deferred features, each marked with ❌ and a one-line reason
6. **User Flows** — step-by-step flows for the primary journeys
7. **Non-Functional Requirements** — performance, security & privacy, accessibility, offline behavior
8. **Open Questions** — a table: `#`, question, owner/source, decision (blank or "Pending"). These block the `build` skill until resolved.

Add, when useful for the release: **Technology & Integrations** (only what changes — Firebase Auth, Firestore, Google Maps/Places, APNs, Rails API), **Implementation Phases** (goal, deliverables, validation per phase), and **Risks & Mitigations** (3–5, each with a specific mitigation).

## Spotique Rules to Respect

- **Privacy model**: full street address and host phone are hidden until a booking is confirmed; driver phone is shared with the host at booking creation. Any feature touching listings or bookings must state what is visible at each stage.
- **Payments are off-platform** (cash, Venmo, Zelle on arrival) — don't specify payment processing unless the release explicitly changes that.
- **Verified identity** is required before any screen; no anonymous flows.
- **Trust model**: thumbs-up/down ratings and no-show tracking; no in-app chat.
- **Geography**: MVP is Jackson Heights, Queens (zip 11372); autocomplete and the map are scoped there.
- Scope features per platform where behavior differs (iOS, Android, API), and note API impacts so `docs/api-contract.md` can be updated.

## Writing Guidelines

- Professional, concrete, and scannable: prefer specific examples (real screens, real values) over abstractions.
- Use ✅ for in-scope and ❌ for out-of-scope items; use tables for metrics and open questions.
- Acceptance criteria must be measurable — avoid "fast" or "easy"; give a number or an observable behavior.
- Keep terminology consistent with `docs/prd-v1.md` and `docs/api-contract.md`.
- Don't invent facts. Anything assumed goes in Open Questions or the final summary.

## Quality Checks

- [ ] Sections follow `docs/prd-v1.md` numbering, with §4 features and §8 open questions present
- [ ] Every feature has a priority, user story, and testable acceptance criteria
- [ ] Out-of-scope items are explicit
- [ ] Privacy model stated wherever addresses or phone numbers appear
- [ ] Success metrics are measurable with timeframes
- [ ] Open questions captured rather than guessed
- [ ] Consistent terminology and no contradictions with the existing PRD or API contract

## After Writing

1. Confirm the file path.
2. Give a brief summary of the PRD.
3. List assumptions and unresolved open questions.
4. Suggest next steps: review and resolve open questions, then run the `tech-spec` skill on each P0 feature, then `build`.
