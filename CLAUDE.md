# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spotique is an hourly private-parking marketplace. Hosts (residents with driveways or garages) list their spots; drivers browse a map, request a time window, and — once the host accepts — receive the full address and the host's phone number to coordinate arrival and payment.

Key product facts that shape the code:

- **MVP geography**: Jackson Heights, Queens, NY (zip 11372). Address autocomplete and the map are scoped to this area.
- **Payments are off-platform**: cash, Venmo, or Zelle, paid on arrival. There is no Stripe/payment integration in MVP.
- **Phone-number auth** is the only identity. A verified US phone number is required to use any screen.
- **Privacy model**: the full street address and host phone are hidden until a booking is confirmed. Driver phone is shared with the host at booking creation.
- **Trust model**: post-booking thumbs-up/down ratings and no-show tracking (no in-app chat).

## Platforms

- **iOS** — Swift + SwiftUI (with SwiftData locally). See [`iOS/CLAUDE.md`](iOS/CLAUDE.md).
- **Android** — Kotlin + Jetpack Compose (TBD).
- **Api** — Rails 8.1 API-only backend. See [`Api/CLAUDE.md`](Api/CLAUDE.md).

## Expected backend services

These are the integrations the PRD plans for; they may not all be wired up yet in code:

- **Firebase Authentication** — phone-number verification (SMS)
- **Cloud Firestore** — listings, bookings, ratings, user profiles; Security Rules enforce per-user access
- **Google Maps + Google Places** — map view and address autocomplete (restricted to 11372)
- **Push notifications** — APNs on iOS, FCM on Android; triggers include new booking request, accept/decline, rating-window open

## Repository Structure

```
iOS/       — iOS app (SwiftUI + SwiftData)
Android/   — Android app (TBD)
Api/       — Rails API backend
```

Each platform directory has its own `CLAUDE.md` with platform-specific build commands, architecture, and conventions. Refer to those when working within a specific platform.

## Key References

- [`docs/prd-v1.md`](docs/prd-v1.md) — PRD v1.0 (MVP): product scope, personas, acceptance criteria, feature requirements
- [`docs/api-contract.md`](docs/api-contract.md) — REST API contract: all endpoints, request/response shapes, validations
- [`.claude/agents.md`](.claude/agents.md) — Multi-agent development workflow guide
- [`.claude/skills/`](.claude/skills/) — Reusable skills for iOS, Android, Rails, Firebase, and full-stack feature development
