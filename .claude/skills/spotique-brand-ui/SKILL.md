---
name: spotique-brand-ui
description: Use for any frontend, design, styling, component, screen, landing page, email, or visual UX work for Spotique across web and mobile.
---

# Spotique Brand UI Skill

Use this skill whenever creating, editing, reviewing, or refactoring any user-facing interface for Spotique across:
- iOS
- Android
- responsive web
- desktop web
- marketing pages
- email
- admin dashboards
- prototypes and mockups

## Brand Colors

- Deep Navy: `#0D1F3C`
- Warm Gold: `#C5943C`
- Ivory: `#F7F3EC`
- Charcoal: `#2C2C2A`

## Color Tokens

Use these names on every platform so iOS, Android, and web stay in sync.

| Color | iOS (asset catalog colorset → Swift) | Android (`ui/theme/Color.kt`) | Web (CSS variable / Tailwind) |
|---|---|---|---|
| Deep Navy | `BrandNavy` → `Color.brandNavy` | `BrandNavy` | `--color-brand-navy` / `brand-navy` |
| Warm Gold | `BrandGold` → `Color.brandGold` | `BrandGold` | `--color-brand-gold` / `brand-gold` |
| Ivory | `BrandIvory` → `Color.brandIvory` | `BrandIvory` | `--color-brand-ivory` / `brand-ivory` |
| Charcoal | `BrandCharcoal` → `Color.brandCharcoal` | `BrandCharcoal` | `--color-brand-charcoal` / `brand-charcoal` |

Semantic roles (Material 3 `ColorScheme` names on Android):

| Role | Color |
|---|---|
| `primary` | Deep Navy |
| `onPrimary` | Ivory |
| `secondary` (accent) | Warm Gold |
| `onSecondary` | Deep Navy |
| `background` / `surface` | Ivory |
| `onBackground` / `onSurface` | Charcoal |

## Contrast Rules

The PRD requires ≥4.5:1 contrast for body text and ≥3:1 for large text and UI components.

| Pairing | Ratio | Allowed for |
|---|---|---|
| Charcoal on Ivory | 12.7:1 | Everything |
| Ivory on Navy | 14.9:1 | Everything |
| Navy on Gold | 6.0:1 | Everything |
| Charcoal on Gold | 5.1:1 | Everything |
| Gold on Navy | 6.0:1 | Everything |
| Gold on Ivory / white | 2.5–2.7:1 | Decoration only (dividers, borders next to other cues) — **never text, icons, or control outlines** |
| Ivory / white on Gold | 2.5–2.7:1 | **Never** |

- Gold text and gold icons belong on navy surfaces only.
- On a gold background, use navy or charcoal text — never ivory or white.
- Never convey state by color alone; pair it with an icon or text label.

## Brand Aesthetic

Spotique should feel like a boutique hospitality brand, not a generic startup app.

Always aim for:
- premium
- calm
- trustworthy
- understated
- urban
- concierge-like

Reference vibe:
- Flatiron members club
- boutique hotel key card
- premium residential concierge brand

Avoid:
- neon colors
- playful startup gradients
- generic SaaS visuals
- cartoonish illustration styles
- harsh white backgrounds
- pure black body text unless absolutely necessary

## UI Defaults

- Prefer ivory backgrounds over pure white
- Prefer charcoal text over pure black
- Use deep navy as the anchor color for headers, nav, major surfaces, and strong brand moments
- Use warm gold sparingly for accents, selected states, highlights, premium CTAs, icons, and dividers
- Favor elegant spacing and restrained hierarchy
- Keep components refined, calm, and premium
- Default to polished, editorial, hospitality-inspired styling

## Component Rules

### Buttons
- Primary: deep navy background with ivory text, or warm gold background with navy text when premium emphasis is needed
- Avoid generic bright-blue CTA styling

### Cards
- Ivory or subtly tinted surfaces
- Soft borders or restrained shadows
- Clean spacing and strong readability

### Typography
- Charcoal for primary text
- Ivory text on navy surfaces
- Strong hierarchy, minimal clutter

### Forms
- Minimal and polished
- Easy to scan
- Refined focus/selected states using navy or gold

### Navigation
- Navy-forward foundation
- Gold used as accent, not overload

## Implementation Rule

When generating frontend code, map brand colors into the platform's theme system rather than scattering hardcoded values.

Examples:
- SwiftUI: centralized `Color` tokens
- Jetpack Compose: `Color.kt` + Material 3 `ColorScheme` in `Theme.kt`
- React / Next.js: CSS variables or theme tokens
- Tailwind: theme extension
- React Native: shared theme object
- Flutter: `ThemeData` / `ColorScheme`

Use the token names from **Color Tokens** above.

**Exception — email:** many email clients (including Outlook and Gmail) don't support CSS variables. In email templates, inline the literal hex values from **Brand Colors**, defined once at the top of the template if the templating system allows it.

## Platform Notes

### iOS (SwiftUI)
- Define each token as a colorset in `iOS/Spotique/Assets.xcassets`; Xcode generates the `Color.brandNavy`-style symbols. Don't use inline `Color(red:green:blue:)` literals in views.
- Set the existing `AccentColor` colorset to Deep Navy so system controls (toggles, links, pickers) tint on-brand. Don't use gold as the accent color — it fails contrast on ivory.
- `List` and `Form` paint their own system background over yours. Apply `.scrollContentBackground(.hidden)` and `.background(Color.brandIvory)`.

### Android (Jetpack Compose)
- Put the tokens in `ui/theme/Color.kt` and build the `ColorScheme` in `Theme.kt` using the semantic roles above.
- Turn off dynamic color: the Android Studio template's `Theme.kt` defaults to `dynamicColor = true`, which on Android 12+ replaces the brand colors with colors taken from the user's wallpaper.
- Read colors from `MaterialTheme.colorScheme` in composables, not from `Color(0xFF…)` literals.

### Web
- Declare the tokens once as CSS variables on `:root` (or in the Tailwind theme extension) and set `body` to ivory with charcoal text.

## Behavior

If the user asks for a screen, flow, component, or frontend implementation without explicit styling direction:
- automatically apply Spotique branding
- do not use generic defaults
- do not leave UI unbranded
- brand the first pass by default unless the user asks for wireframe-only output
