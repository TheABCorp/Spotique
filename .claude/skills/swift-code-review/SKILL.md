---
name: swift-code-review
description: Review Swift/SwiftUI changes in Spotique iOS for correctness, concurrency safety, memory, architecture, accessibility, privacy, and test coverage.
argument-hint: "[files-or-diff]"
---

# Skill: Swift Code Review (Spotique iOS)

Use to review a diff or set of files under `iOS/`. Default scope is the current branch versus `main` (`git diff main...HEAD -- iOS`).

## Process

1. Read `iOS/CLAUDE.md` for conventions, and any linked skill relevant to the change (`mvvm-architecture`, `swiftui-development`, `swift-concurrency-6-2`).
2. Read the changed code *and* enough surrounding code to understand how it's used.
3. Build/test if feasible (commands in `iOS/CLAUDE.md`) to confirm the code compiles and tests pass.
4. Report findings ordered by severity. Cite `file:line`, explain the failure scenario, and suggest a fix. Don't pad with nitpicks or restate what's fine.

## What to Check

**Correctness & Swift idioms**
- Optionals: no force unwraps (`!`, `try!`, `as!`) outside tests/previews without justification
- Value types preferred; protocols used for seams, not everywhere
- Access control as tight as practical (`private`, `private(set)`)
- Swift API Design Guidelines for naming

**Concurrency**
- UI-driving types are `@MainActor`; data crossing actors is `Sendable`
- No `DispatchQueue`/locks in new code where actors/async fit (see `swift-concurrency-6-2`, `swift-actor-persistence`)
- No unstructured `Task {}` that outlives its owner without cancellation; long work checks `Task.isCancelled`
- No `nonisolated(unsafe)` / `@unchecked Sendable` without a written reason

**Memory**
- Closures stored on long-lived objects use `[weak self]`; look for retain cycles in observers, timers, and delegate wrappers (e.g. the Google Maps wrapper)

**Architecture**
- MVVM boundaries respected: no logic in views, no UI types in ViewModels, services behind protocols
- `@Observable` (not `ObservableObject`/Combine); SwiftData used via `@Query`/`ModelContext`
- Models match `docs/api-contract.md`

**SwiftUI**
- State ownership is correct (`@State`/`@Bindable`/`@Environment`); no work in `body`
- Lazy containers for long lists; stable identities
- Accessibility labels, Dynamic Type, dark mode, 44pt targets

**Security & privacy** (see `ios-security-review`)
- No secrets/tokens in code, logs, or UserDefaults; Keychain for credentials
- Full street address and host phone never displayed, logged, cached, or persisted before booking confirmation
- Driver phone is shared with the host only at booking creation

**Tests**
- New/changed ViewModels have Swift Testing tests including failure paths
- Tests are deterministic (no real network, no sleeps)

## Output Format

```
### Critical / High / Medium / Low
- `path/File.swift:42` — <what's wrong>. <Why it matters / how it fails>. <Suggested fix>.
```

End with a one-line verdict: approve, approve with nits, or changes requested. If nothing is wrong, say so plainly.
