# Skill: Brand Style

Ensure frontend UI changes (iOS now, Android once client work starts) follow Spotique's brand colors, typography, and visual style consistently.

## When to Use

Before building or modifying any screen, view, or reusable UI component on iOS or Android — new features, redesigns, and one-off UI tweaks alike.

## Before You Start

1. Read the token reference below — it is the single source of truth for colors, type scale, spacing, and shape.
2. Check the platform's existing named tokens (iOS: `Assets.xcassets`; Android: `ui/theme/Color.kt`) before adding a new one — reuse an existing semantic token if one already fits.
3. If official brand assets (logo, hex codes, style guide) become available, update the values in **this file first**, then propagate the change to platform color assets. Never let a platform file and this file disagree.

## Brand Personality

Spotique is a friendly, trustworthy, local marketplace — closer to "your neighbor's driveway" than a corporate parking garage app. The UI should read as approachable, warm, and low-friction: not cold/enterprise (no navy-suit fintech look), and not flashy/gig-economy neon either.

## Color Palette

> **Placeholder pending official brand assets.** These hex values were chosen to fit the brand personality above and are not yet signed off by a designer. Treat them as real defaults to build against, but swap them out here the moment official colors exist.

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#1B7A6E` | `#3FA396` | Brand color — nav, primary buttons, active states |
| `primaryPressed` | `#14574F` | `#2C7A70` | Pressed/hover state of `primary` |
| `accent` | `#F5A623` | `#F5A623` | Primary CTA emphasis (e.g. "Request to Book") |
| `success` | `#2E9E5B` | `#4CBE78` | Booking accepted, active/confirmed states |
| `warning` | `#D98C00` | `#E0A639` | Pending, expiring soon |
| `error` | `#D64545` | `#E86A6A` | Declined, no-show, destructive actions |
| `background` | `#FAFAF7` | `#121412` | Screen background |
| `surface` | `#FFFFFF` | `#1E211F` | Cards, sheets, elevated content |
| `textPrimary` | `#1A1A1A` | `#F2F2F0` | Primary text |
| `textSecondary` | `#6B6B65` | `#A8A8A2` | Secondary/supporting text |
| `border` | `#E4E2DB` | `#33362F` | Dividers, input borders |

Both a light and a dark value are required for every token — the app must support Dark Mode from the start.

## Typography

- Use the platform's native system font (SF Pro on iOS, Roboto on Android) — no custom font in MVP. This keeps the app feeling native and avoids load-time/licensing overhead.
- Type scale (name / size / weight):
  - Title — 28 / Bold
  - Headline — 20 / Semibold
  - Body — 16 / Regular
  - Caption — 13 / Regular
- No ad hoc font sizes or weights outside this scale.

## Spacing & Shape

- Spacing scale (4pt/dp base unit): 4, 8, 12, 16, 24, 32.
- Corner radius: 12pt/dp for cards and buttons, 8pt/dp for input fields, fully rounded for pills/badges (e.g. status chips).
- Elevation: a single subtle shadow on cards only (small y-offset, soft blur, low opacity) — avoid heavy skeuomorphism.

## Component Rules

- **Primary CTA button**: solid `primary` background, white text, 12pt/dp radius, full-width on mobile forms.
- **Secondary/ghost button**: `primary` text and border, transparent background.
- **Status badges** (pending / confirmed / declined / no-show): pill-shaped, semantic color at low-opacity background with full-opacity text/icon — never rely on color alone, always pair with an icon or text label (matches the PRD's accessibility requirement).
- **Map pins/listing markers**: `primary` for default pins, `accent` for the user's selected/active spot.

## Implementation

### iOS

- Add/maintain one colorset per semantic token in `iOS/Spotique/Assets.xcassets`, each with Any + Dark appearance variants matching the table above. Reference colors via `Color("primary")`, etc.
- Never use inline hex literals (`Color(red:green:blue:)` or a `Color(hex:)` helper) directly in view code — always go through a named asset.
- Centralize the type scale (e.g. a `Typography` enum or `Font` extension) rather than repeating `.font(.system(size:weight:))` inline.

### Android (once client work starts)

- Define the same semantic tokens in `ui/theme/Color.kt` and wire them into the Material3 `ColorScheme` in `Theme.kt`, with light/dark variants.
- Define the type scale in `ui/theme/Type.kt`.

## Review Checklist

Apply to every frontend change before considering it done:

- [ ] No hardcoded hex/RGB literals in view code — only semantic tokens from `Assets.xcassets` / `Color.kt`
- [ ] A new color is added to this file first (with its use case documented) before it's added to a platform color asset
- [ ] Both light and dark values are provided for any new or changed token
- [ ] Contrast meets the PRD's accessibility bar (≥4.5:1 for body text, ≥3:1 for large text/UI components) — check any new color pairing
- [ ] Status/error states never rely on color alone — an icon or text label is present too
- [ ] Font sizes/weights match the defined type scale
- [ ] Spacing and corner radius values match the scale and shape rules above
