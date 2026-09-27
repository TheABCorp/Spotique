---
name: full-stack-feature
description: Implement a feature across all platforms - Rails API, iOS, and Android.
---

# Skill: Full-Stack Feature

Implement a feature across all platforms: Rails API, iOS, and Android.

## Before You Start

1. Read `CLAUDE.md` for project context.
2. Read `docs/api-contract.md` — verify the endpoint exists or define it.
3. Read each platform's `CLAUDE.md` for conventions.

## Implementation Order

### Phase 1: API Contract

1. Define or verify the endpoint in `docs/api-contract.md`.
2. Specify request/response shapes, status codes, and error cases.
3. Commit the contract update before moving to implementation.

### Phase 2: Rails API

1. Follow the `rails-api` skill to implement the endpoint.
2. Write request specs covering happy path, auth, validation, and edge cases.
3. Verify specs pass: `cd Api && bundle exec rspec`.

### Phase 3: iOS + Android (parallel)

Run these in parallel using separate agents:

**iOS** (follow `iOS/CLAUDE.md` and its listed skills: `swift-concurrency-6-2`, `liquid-glass-design`, `swift-actor-persistence`):
1. Create model matching the API contract.
2. Create service calling the endpoint.
3. Create ViewModel with state management.
4. Build SwiftUI view, following the `spotique-brand-ui` skill for colors/typography/spacing.
5. Write ViewModel tests.

**Android** (follow `android-feature` skill):
1. Create data class matching the API contract.
2. Create Retrofit API interface.
3. Create repository.
4. Create ViewModel with StateFlow.
5. Build Composable, following the `spotique-brand-ui` skill for colors/typography/spacing.
6. Write ViewModel tests.

### Phase 4: Integration Verification

1. Verify all platforms handle the same status codes and error shapes.
2. Verify field names match the API contract exactly.
3. Verify privacy rules are enforced (no address/phone leakage before confirmation).
4. Verify push notification triggers are wired up if applicable.

## Multi-Agent Execution

To run phases 3 in parallel, use the Task tool:

```
Launch two agents simultaneously:
- iOS agent: "Implement [feature] in iOS/ following iOS/CLAUDE.md and docs/api-contract.md"
- Android agent: "Implement [feature] in Android/ following .claude/skills/android-feature.md and docs/api-contract.md"
```

See `.claude/agents.md` for full multi-agent workflow details.
