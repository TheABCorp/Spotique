---
name: ios-performance
description: Profile and optimize Spotique iOS performance — launch time, SwiftUI rendering, map and list scrolling, memory, networking, and battery — using Instruments.
argument-hint: "[screen-or-flow]"
---

# Skill: iOS Performance (Spotique)

Use when the app feels slow, drops frames, uses too much memory or battery, or before optimizing anything. **Measure first, change one thing, measure again.**

## Method

1. **Define the problem** — which screen/flow, on what device and iOS version, with what data volume (e.g. many listings on the map).
2. **Baseline** — profile a Release build on a real device where possible (simulator numbers are unreliable). Record the metric.
3. **Find the hot spot** with the right instrument (below).
4. **Optimize** the biggest contributor only.
5. **Re-measure** and compare against the baseline. Keep the change only if it moves the metric.

## Targets (guidelines, verify on-device)

- Cold launch to first interactive frame: fast enough to feel instant; avoid work before the first frame.
- Scrolling lists and map panning: sustained 60fps (120 on ProMotion) with no visible hitches.
- No memory growth when navigating in and out of a screen repeatedly.
- Network: minimal requests per screen, no duplicate fetches.

## Instruments Guide

| Question | Instrument |
|----------|------------|
| What is the CPU doing / what blocks main? | Time Profiler, Hangs |
| Why is SwiftUI re-rendering? | SwiftUI instrument (view body updates), `Self._printChanges()` |
| Memory growth or leaks? | Allocations, Leaks, Memory Graph |
| Slow launch? | App Launch template |
| Battery/thermal? | Energy Log |
| Network chatter? | Network instrument |
| Dropped frames? | Animation Hitches |

## Spotique-Specific Hot Spots

- **Map with many markers** — cluster markers at low zoom, only render markers in the visible region, reuse marker views/icons, and debounce region-change fetches.
- **Listing lists** — `LazyVStack`/`List` with stable ids; downsample images to display size; cache decoded images; avoid per-row formatter creation.
- **Address autocomplete** — debounce keystrokes (~250–300 ms) and cancel in-flight requests; restrict to zip 11372.
- **Images** — request appropriately sized images, decode off the main actor, and cache.
- **Launch** — defer SDK setup (Firebase, Maps) work that isn't needed for the first screen; don't block on network.
- **Background/battery** — limit location accuracy and update frequency to what the feature needs; batch network work; no polling when a push can notify.

## SwiftUI Rendering

- Keep `body` cheap; do computation in the ViewModel or cache it.
- Narrow what each subview observes so unrelated state changes don't re-render it.
- Use stable, cheap identities in `ForEach`; avoid `AnyView`.
- Avoid heavy `GeometryReader`/`onAppear` work in list rows; consider `drawingGroup()` only after profiling.

## SwiftUI Performance Patterns

- **Cache static view data as properties**, not rebuilt in `body`:
  ```swift
  private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]   // ✅
  LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2)) { … }  // ❌ allocates every render
  ```
- **Precompute display metadata in the ViewModel** with static dictionaries (O(1)) instead of `switch` on strings inside view code; use `lazy var` for expensive one-time derived values.
- **Compare strings efficiently**: `caseInsensitiveCompare(_:) == .orderedSame` instead of `lowercased() == lowercased()`, which allocates two strings per comparison.
- **Keep computed properties cheap** (simple boolean logic). Move validation, I/O, or heavy work to methods or cached state.
- **Pass value types** (`Sendable` structs) to child views; keep `ForEach` closures minimal, extracting complex logic to methods.
- **Scope animations to a value**: `.animation(.spring(response: 0.3), value: flag)`, never a bare `.animation(.default)`.
- A brief delay to show success feedback before dismissing (~0.6–0.8 s) is fine; don't add sleeps elsewhere.

### Anti-Patterns

1. Recreating arrays/dictionaries in `body`
2. String operations during rendering (capitalizing, lowercasing, formatting)
3. Long `switch` statements on strings in hot paths
4. Creating heavy closures in `ForEach`
5. Unbounded animations
6. Heavy computation in computed properties

### Checklist

- [ ] Static view components cached as properties
- [ ] String lookups use dictionaries; comparisons use `caseInsensitiveCompare`
- [ ] Computed properties are lightweight
- [ ] Animations bound to specific values
- [ ] No collection recreation in `body`; `ForEach` closures minimal

## Concurrency

- Move CPU-heavy work (decoding large payloads, clustering, image processing) off the main actor with `@concurrent` (see `swift-concurrency-6-2`); network calls are already async and don't need it.
- Cancel work when a view disappears or input changes.

## Regression Guards

- Add `XCTest` `measure` blocks or Swift Testing time checks for hot algorithms (e.g. clustering) when practical.
- Note the before/after numbers in the PR description.

## Output

Report: baseline metric, bottleneck with evidence (instrument + `file:line`), change made, and after metric.
