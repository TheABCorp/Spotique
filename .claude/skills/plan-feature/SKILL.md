---
name: plan-feature
description: Turn a PRD (or PRD section) or a set of requirements into a codebase-grounded, step-by-step implementation plan for Spotique, written to docs/plans/. Plans only — no code.
argument-hint: "<path-to-PRD[#section]> | <requirements text>"
---

# Skill: Plan Feature

Transform a PRD or a set of requirements into a **comprehensive implementation plan** through codebase analysis, targeted research, and strategic planning.

**We do NOT write code in this skill.** The goal is a context-rich plan that lets an implementation agent succeed in one pass.

**Context is king.** The plan must contain everything needed to implement: the patterns to mirror, files to read first, docs to consult, and validation commands for every task.

## Input (required)

`$ARGUMENTS` must be one of:

1. **A PRD reference** — a path to a PRD, optionally with a section or feature name, e.g.:
   - `docs/prd-v1.md`
   - `docs/prd-v1.md#4.4` or `docs/prd-v1.md "P0 — Request Booking"`
2. **A set of requirements** — free text, a bulleted list, or a path to a file containing requirements (a spec, ticket, or notes).

If `$ARGUMENTS` is empty, or is too vague to plan from (no identifiable feature or problem), **stop and ask the user** for a PRD reference or requirements. Do not invent a feature.

If a PRD path is given without a section and the PRD contains many features, list the P0/P1 features and ask which to plan.

An existing tech spec (`docs/specs/<slug>.md`) may also be passed as requirements. If one already exists for the feature, use it as a source and don't duplicate it — this plan adds the codebase-level implementation detail the spec doesn't have.

## Planning Process

### Phase 1: Requirements Understanding

- Read the input in full. For a PRD, read the target section and copy its **acceptance criteria verbatim**; also read the sections that constrain it (§7 non-functional requirements, §4.7 notifications, §8 open questions, out-of-scope list).
- Extract the core problem, user value, and who is affected (host, driver, or both).
- Classify: New Capability / Enhancement / Refactor / Bug Fix. Assess complexity: Low / Medium / High.
- Write or refine the user story: *As a <user>, I want <action>, so that <benefit>.*
- Identify which platforms are involved: **Api** (Rails), **iOS**, **Android** — and note that the API is implemented first, then clients (see `.claude/agents.md`).
- **Requirements gaps**: list anything ambiguous, contradictory, or missing. If it blocks planning, ask the user before continuing; otherwise record it as an open question in the plan. Never guess at product decisions.

### Phase 2: Codebase Intelligence

Use parallel exploration (e.g. the Explore agent) for breadth, and read key files yourself.

1. **Project context** — `CLAUDE.md`, plus `Api/CLAUDE.md`, `iOS/CLAUDE.md`, `Android/CLAUDE.md` for each affected platform (architecture, conventions, build/test commands).
2. **Contracts** — `docs/api-contract.md` for existing endpoints, shapes, and validations. Note contract gaps; the contract is the single source of truth.
3. **Existing specs and prior work** — `docs/specs/`, plus recent `git log` for the affected areas.
4. **Pattern recognition** — find the closest similar implementation in each affected platform and record: naming, file organization, error handling, logging, and how it's tested. Capture real code excerpts with `file:line`.
5. **Integration points** — existing files to update; new files to create and where; route/serializer/registration patterns (Rails), navigation and dependency wiring (iOS/Android), schema and migrations.
6. **Relevant skills** — identify the project skills that apply and reference them in the plan rather than restating them, e.g. `rails-api`, `rails-schema-design`, `mvvm-architecture`, `swiftui-development`, `ios-api-client`, `swift-concurrency-6-2`, `android-feature`, `spotique-brand-ui`.
7. **Testing patterns** — test frameworks, similar tests to mirror, and standards (Rails request specs; Swift Testing ViewModel tests; Android ViewModel tests).

### Phase 3: External Research (only where needed)

Research only what the codebase and existing docs can't answer — e.g. a Firebase, Google Maps/Places, or APNs API the feature newly touches. Prefer official docs, link to specific sections, note version constraints and known gotchas. Skip this phase if nothing is new.

### Phase 4: Strategic Thinking

- How does this fit the existing architecture, and what is the correct order of operations (API → iOS/Android)?
- What could go wrong: edge cases, races (e.g. two drivers requesting overlapping windows), offline behavior, failure paths?
- **Privacy model check**: what is visible to whom at each booking stage? Full address and host phone stay hidden until a booking is confirmed; driver phone is shared with the host at booking creation. The plan must state how the server enforces this and that clients never hold hidden data early.
- Payments are off-platform; identity must be verified; no in-app chat. Flag any requirement that conflicts with these.
- Security, performance, testability, maintainability. Pick between alternatives with explicit rationale.

### Phase 5: Write the Plan

**Filename:** `docs/plans/<kebab-case-feature-name>.md` (create `docs/plans/` if missing). If the file already exists, ask before overwriting.

Use this template:

```markdown
# Feature: <feature-name>

> Validate documentation, codebase patterns, and task sanity before implementing. Pay special attention to the naming of existing types, models, and utilities, and import from the right files.

**Source:** <PRD path + section, spec path, or "requirements provided in conversation">

## Feature Description
<What the feature does and its value>

## User Story
As a <user> / I want to <action> / So that <benefit>

## Problem Statement
<The specific problem or opportunity>

## Solution Statement
<Proposed approach and why>

## Requirements & Acceptance Criteria
<Verbatim from the PRD, or the user-supplied requirements normalized into testable criteria>

## Feature Metadata
**Feature Type**: New Capability | Enhancement | Refactor | Bug Fix
**Estimated Complexity**: Low | Medium | High
**Platforms**: Api | iOS | Android
**Primary Systems Affected**: <components>
**Dependencies**: <libraries/services>

---

## CONTEXT REFERENCES

### Codebase Files — READ THESE BEFORE IMPLEMENTING
- `path/to/file` (lines a–b) — Why: <pattern to mirror>

### New Files to Create
- `path/to/new_file` — <purpose>

### Documentation — READ BEFORE IMPLEMENTING
- [Title](url#section) — Why: <reason>
- `docs/api-contract.md` § <section> — Why: <endpoints used>

### Skills to Apply
- `<skill-name>` — <what it covers for this feature>

### Patterns to Follow
<Real excerpts from this codebase: naming, error handling, logging, testing, per platform>

---

## PRIVACY & SECURITY
<What is visible to whom at each booking stage; auth requirements; how the server enforces it>

## IMPLEMENTATION PLAN

### Phase 1: Foundation — <schemas/migrations, models, contract updates>
### Phase 2: Core Implementation — <Api endpoint/logic first, then iOS, then Android>
### Phase 3: Integration — <wiring, navigation, notifications, config>
### Phase 4: Testing & Validation

---

## STEP-BY-STEP TASKS

Execute in order, top to bottom. Each task is atomic and independently testable.

Actions: CREATE, UPDATE, ADD, REMOVE, REFACTOR, MIRROR.

### {ACTION} {target_file}
- **IMPLEMENT**: <specific detail>
- **PATTERN**: <file:line to mirror>
- **IMPORTS**: <dependencies>
- **GOTCHA**: <known constraint>
- **VALIDATE**: `<executable, non-interactive command>`

---

## TESTING STRATEGY
### Unit Tests / Integration Tests / Edge Cases
<Per platform, following existing test patterns>

## VALIDATION COMMANDS
<Use the build/test commands from each platform's CLAUDE.md>
### Level 1: Syntax & Style
### Level 2: Unit Tests
### Level 3: Integration Tests
### Level 4: Manual Validation

## OPEN QUESTIONS
| # | Question | Source | Decision |
|---|----------|--------|----------|

## ACCEPTANCE CRITERIA
- [ ] <criteria mapped from requirements>
- [ ] All validation commands pass
- [ ] No regressions; conventions followed
- [ ] Privacy model upheld (no early exposure of address/host phone)
- [ ] `docs/api-contract.md` updated if endpoints changed

## COMPLETION CHECKLIST
- [ ] All tasks completed in order, each validated
- [ ] Full test suites pass on each affected platform
- [ ] Acceptance criteria met

## NOTES
<Design decisions, trade-offs, assumptions>
```

## Quality Criteria

- **Context complete** — patterns, docs, integration points, and gotchas are documented; every task has an executable validation command.
- **Implementation ready** — tasks are ordered by dependency, atomic, and reference specific `file:line` patterns.
- **Pattern consistent** — follows existing conventions; no reinvented utilities; new patterns justified.
- **No prior knowledge needed** — someone unfamiliar with the codebase could implement from the plan alone.
- **Open questions surfaced** — nothing guessed; unresolved items are listed and block implementation.

## Report

After writing the plan, report:

- Summary of the feature and approach
- Path to the plan file
- Complexity and platforms involved
- Key risks, assumptions, and open questions
- Confidence score (#/10) for one-pass implementation, and what would raise it

Suggested next step: resolve open questions, then implement the plan (or run `build` if a tech spec exists).
