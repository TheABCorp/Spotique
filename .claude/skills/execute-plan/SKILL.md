---
name: execute-plan
description: Implement a Spotique implementation plan (from plan-feature, docs/plans/) task by task, run its validation commands, and report results. Input is the path to a plan file.
argument-hint: "<path-to-plan>"
---

# Skill: Execute Plan

Implement a feature by following an implementation plan, typically one written by the `plan-feature` skill to `docs/plans/<slug>.md`.

## Input (required)

`$ARGUMENTS` must be the path to a plan file. If it's empty, or the file doesn't exist, list the files in `docs/plans/` and ask which to execute. Do not proceed without a plan.

## Preflight

1. **Read the ENTIRE plan** — tasks, dependencies, context references, testing strategy, validation commands, acceptance criteria, and notes.
2. **Check for blockers** — if the plan's Open Questions table has any row without a decision (blank or "Pending"), stop and ask the user to resolve them. Do not guess at product decisions.
3. **Check the branch** — never work on `main`. If on `main`, create a new branch first (repo convention: `ab/<short-description>`). If the current branch is unrelated to this feature, ask before continuing on it.
4. **Read the referenced context** — every file under "Codebase Files — READ THESE BEFORE IMPLEMENTING", the API contract sections listed, and the platform `CLAUDE.md` for each platform the plan touches (`Api/CLAUDE.md`, `iOS/CLAUDE.md`, `Android/CLAUDE.md`). Load the skills the plan lists under "Skills to Apply" (e.g. `rails-api`, `mvvm-architecture`, `swiftui-development`, `ios-api-client`, `spotique-brand-ui`).
5. **Sanity-check the plan against the code** — confirm referenced files, types, and line ranges still exist and match. If the plan is stale or wrong in a way that affects the approach, say so and adjust (see Deviations).
6. Confirm the working tree is clean enough to attribute changes to this work (`git status`).

## Execute Tasks in Order

Work through "Step-by-Step Tasks" top to bottom. The plan orders **Api first, then iOS/Android** — keep that order; clients depend on the API contract.

For each task:

1. **Locate** — identify the target file and the action (CREATE, UPDATE, ADD, REMOVE, REFACTOR, MIRROR). Read existing related code before modifying.
2. **Implement** — follow the task's IMPLEMENT / PATTERN / IMPORTS / GOTCHA notes. Mirror the referenced pattern rather than inventing a new one. Match the surrounding code's naming, comment density, and idioms.
3. **Validate immediately** — run the task's VALIDATE command. If it fails, fix and re-run before moving on. Don't accumulate failures.
4. **Track progress** — keep a running checklist of tasks so the final report is accurate.

### Platform Rules

- **Api (Rails)** — follow `Api/CLAUDE.md` and the `rails-api` / `rails-schema-design` skills. Write request specs. Migrations must be reversible and match the schema conventions.
- **iOS** — follow `iOS/CLAUDE.md`: `@Observable` + `@MainActor` ViewModels, protocol-based services, `async/await`, no Combine, brand tokens from `spotique-brand-ui`. Write Swift Testing unit tests for every ViewModel.
- **Android** — follow `Android/CLAUDE.md` and the `android-feature` skill. Write ViewModel tests.
- **Contract** — `docs/api-contract.md` is the source of truth for request/response shapes. If the plan changes an endpoint, update the contract in the same change; never duplicate data models by hand.

### Product Rules (never violate)

- **Privacy model**: the full street address and host phone are hidden until a booking is confirmed; driver phone is shared with the host at booking creation. Enforce on the server, and don't fetch, hold, cache, log, or display hidden data on clients early.
- **Payments are off-platform**; identity must be verified before any screen; no in-app chat.
- Never commit secrets, API keys, or `GoogleService-Info.plist` contents.

## Implement the Testing Strategy

After the implementation tasks:

- Create every test file and test case the plan specifies, including the listed edge cases.
- Follow existing test patterns (request specs for the API, Swift Testing for iOS ViewModels, ViewModel tests for Android).
- Tests must be deterministic: no real network, no `sleep`s, no dependence on live Firebase or SMS.

## Run Validation Commands

Run **all** validation commands from the plan, in order (levels 1–4), exactly as written — commands normally come from each platform's `CLAUDE.md` (e.g. `cd Api && bundle exec rspec`, the `xcodebuild … test` commands for iOS).

- If a command fails: diagnose the root cause, fix it, and re-run. Continue only when it passes.
- Don't skip, weaken, or delete tests or checks to get green. If a check genuinely can't run in this environment (e.g. no simulator, missing credentials), say so explicitly instead of claiming it passed.
- Manual validation steps (Level 4) that can't be automated are listed in the report as "not run" with the steps left for the user.

## Final Verification

Before reporting, confirm:

- [ ] All tasks in the plan are completed
- [ ] All specified tests exist and pass
- [ ] All validation commands pass (or are explicitly reported as not run, with why)
- [ ] Acceptance criteria checked off, one by one, against the actual behavior
- [ ] Code follows project conventions; no stray debug code or unrelated changes
- [ ] `docs/api-contract.md` and platform `CLAUDE.md` files updated if endpoints, dependencies, or conventions changed
- [ ] Privacy model upheld

## Deviations

If you must deviate from the plan (stale reference, a better-fitting existing pattern, a discovered constraint), keep the change minimal, and record it: what changed, why, and its impact. Update the plan file's NOTES section with the deviation. If the deviation changes scope or product behavior, stop and ask first.

If you hit an issue the plan doesn't address, document it rather than silently working around it.

## Commits

Do not commit unless the user asks. When they do:

- Work on a feature branch, never `main`.
- **No AI attribution** — no `Co-Authored-By: Claude` trailer, no `Claude-Session:` line, no "Generated with Claude Code" footer, in commits or PR text.
- Prefer logical commits (e.g. API, then iOS, then Android) with clear messages.

## Output Report

### Completed Tasks
- Each task done, with files created and modified (paths)

### Tests Added
- Test files and cases, with results

### Validation Results
- Each validation command and its outcome (paste key output; note any not run and why)

### Acceptance Criteria
- Each criterion with pass / not verified

### Deviations & Issues
- Any departures from the plan, unresolved issues, or follow-ups

### Ready for Commit
- Confirm whether all changes are complete and validated. Ask the user whether to commit (and open a PR).
