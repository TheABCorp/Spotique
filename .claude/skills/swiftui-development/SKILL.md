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

## Design Principles (Apple HIG)

All new views follow Apple's Human Interface Guidelines: **Clarity** (content first; UI clarifies rather than competes), **Deference** (the interface helps people interact with content), **Depth** (layers and motion convey hierarchy). Combine with `spotique-brand-ui` for branding.

## Forms & Input

- Use native controls (`TextField`, `DatePicker`, `Form`/`Section`, `Toggle`, `Picker`) with system styling and spacing. Build custom controls only when native ones can't do the job.
- **Typography**: semantic styles (`.headline`, `.body`, `.caption`), never fixed point sizes, so Dynamic Type works.
- **Keyboards & content types**: set `keyboardType`, `textContentType`, and `textInputAutocapitalization` to fit the field — e.g. `.telephoneNumber` for phone entry, `.oneTimeCode` for the SMS verification code, `.fullStreetAddress` for address fields.
- **Focus**: manage focus with `@FocusState` and an enum of fields; move focus logically through the form (`.submitLabel(.next)` + `onSubmit`).
- **Real-time validation**: validate in the ViewModel and show helpful, non-intrusive feedback (e.g. a character count that turns to a warning color near the limit); disable the primary action until the form is valid.
- **Errors**: show clear, actionable messages from ViewModel error state, with a way to recover.
- **Loading**: keep loading non-blocking — disable the action and show a `ProgressView` overlay while a save/submit is in flight.
- **Presentation**: standard navigation — `NavigationStack`, inline title for forms, `.cancellationAction` for Cancel and `.confirmationAction` for Save/Submit in the toolbar. Wrap main screen content in a shared base view if the app adds one (e.g. for an offline banner).

## Localization

- SwiftUI labels take plain string literals (implicit `LocalizedStringKey`): `Button("Save")`, `Section("Name")`, `.navigationTitle("Edit")`, `.accessibilityLabel("Save")`.
- ViewModel and model strings (error messages, validation text, computed display strings) use explicit `String(localized:)`.
- Fallback values (`?? "Unknown"`) that must produce a `String` use `String(localized:)`.
- After adding or changing user-facing text, confirm every new string has an entry in `Localizable.xcstrings`, and that nothing user-facing bypasses localization.

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
- [ ] Native controls, semantic fonts, and correct keyboard/`textContentType` settings
- [ ] New user-facing strings are localized and in `Localizable.xcstrings`
- [ ] No exact address or host phone shown before a booking is confirmed
