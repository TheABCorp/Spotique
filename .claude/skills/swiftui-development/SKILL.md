---
name: swiftui-development
description: Build Spotique iOS SwiftUI views — composition, state, navigation, animation, accessibility, previews, and performance, following the Spotique brand.
argument-hint: "[screen-or-component]"
---

# Skill: SwiftUI Development (Spotique iOS)

Use when creating or modifying SwiftUI screens and components in `iOS/`.

## Before You Start

1. Read `iOS/CLAUDE.md` (targets iOS 26.1, MVVM with `@Observable`).
2. Load the `spotique-brand-ui` skill for colors, typography, and spacing. Use brand tokens, not ad-hoc values.
3. For glass/materials on toolbars and floating map controls, see `liquid-glass-design`.
4. For ViewModel structure, see `mvvm-architecture`.

## Composition

- Small, single-purpose views. Extract a subview when `body` exceeds ~40 lines or a chunk is reused.
- Keep views free of business logic; they render ViewModel state and forward intent.
- Reusable pieces (listing card, price/time row, status chip, primary button) live in a shared components folder, styled via custom `ButtonStyle`/`ViewModifier` so brand styling is defined once.

## State

| Need | Use |
|------|-----|
| View-local value | `@State` |
| View owns an `@Observable` ViewModel | `@State private var viewModel` |
| Bindings into an injected `@Observable` | `@Bindable` |
| App-wide dependency or system value | `@Environment` |
| SwiftData fetch | `@Query`, writes via `@Environment(\.modelContext)` |

Do not use `@StateObject`/`@ObservedObject`/`@EnvironmentObject` — the project uses the Observation framework.

## Layout & Lists

- Stacks and `Grid` first; `GeometryReader` only when unavoidable; custom `Layout` for genuinely custom arrangements.
- `LazyVStack`/`List` for anything scrollable with many rows (listings, bookings). Give rows stable `id`s.
- Respect safe areas; never hard-code device sizes.

## Maps

- The map is Google Maps (see `iOS/CLAUDE.md`), wrapped for SwiftUI. Keep the wrapper thin and drive it from ViewModel state (visible listings, selection).
- Before booking confirmation, show only the approximate location; never render the exact street address.

## Animation

- `withAnimation` for state-driven changes, `.animation(_:value:)` for implicit ones — always scoped to a value.
- Prefer spring animations, `matchedGeometryEffect` for card → detail transitions, and `contentTransition` for changing text/numbers.
- Respect `accessibilityReduceMotion`.

## Accessibility (required)

- Every interactive element has an accessibility label; combine composite rows with `accessibilityElement(children: .combine)`.
- Support Dynamic Type (no fixed font sizes; test at the largest sizes) and verify contrast in light and dark mode.
- Minimum 44×44pt tap targets.
- Add `accessibilityIdentifier`s to elements UI tests need.

## Previews

- Provide `#Preview` for each meaningful state: loading, empty, populated, error, long text, dark mode, large Dynamic Type.
- Use fake services so previews don't hit the network.

## Performance

- Keep `body` cheap; move formatting and filtering into the ViewModel.
- Avoid creating formatters/objects inside `body`.
- Narrow observation: pass only what a subview needs so unrelated changes don't re-render it.
- If scrolling or transitions hitch, profile using the `ios-performance` skill.

## Checklist

- [ ] Brand tokens used (`spotique-brand-ui`)
- [ ] `@Observable` patterns only; no `ObservableObject`
- [ ] Loading, empty, and error states handled
- [ ] Accessibility labels, Dynamic Type, dark mode verified
- [ ] Previews for each state
- [ ] No exact address or host phone shown before a booking is confirmed
