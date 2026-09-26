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
- Primary: deep navy background with ivory text, or warm gold accent when premium emphasis is needed
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
- React / Next.js: CSS variables or theme tokens
- Tailwind: theme extension
- React Native: shared theme object
- Flutter: `ThemeData` / `ColorScheme`

## Behavior

If the user asks for a screen, flow, component, or frontend implementation without explicit styling direction:
- automatically apply Spotique branding
- do not use generic defaults
- do not leave UI unbranded
- brand the first pass by default unless the user asks for wireframe-only output
