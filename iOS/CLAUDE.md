# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spotique is an iOS app built with SwiftUI and SwiftData. It targets iOS 26.1, uses Swift 5, and has bundle identifier `com.actionman.Spotique`.

## Build & Test Commands

```bash
# Build
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator build

# Run unit tests
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test
xcodebuild -project Spotique.xcodeproj -scheme Spotique -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SpotiqueTests/SpotiqueTests/example test
```

## Architecture

- **MVVM** — Views observe ViewModels (`@Observable`), ViewModels call services/repositories, models are plain structs or `@Model` classes.
- **SwiftUI + SwiftData** — SwiftData for local persistence with `@Model` classes and `ModelContainer`/`ModelContext`.
- **Entry point**: `SpotiqueApp.swift` — sets up the `ModelContainer` with the schema and injects it via `.modelContainer()`.
- **Data models**: Defined in `Spotique/` as `@Model` classes (currently `Item`).
- **Views**: SwiftUI views using `@Query` for reactive data fetching and `@Environment(\.modelContext)` for writes.
- **Tests**: Unit tests use Swift Testing framework (`import Testing`, `@Test`). UI tests use XCTest/XCUIApplication.

## Key Dependencies

- **Firebase Auth** — Phone-number SMS verification (the only auth method)
- **Cloud Firestore** — Remote data store for listings, bookings, ratings, user profiles
- **Google Maps SDK for iOS** — Map view and address autocomplete (scoped to Jackson Heights 11372)
- **APNs** — Push notifications for booking lifecycle events

## Conventions

- Use `async/await` for all asynchronous work; avoid Combine unless wrapping a delegate-based API.
- ViewModels should be `@Observable` classes with `@MainActor` when they drive UI state.
- Write unit tests for every ViewModel. Mock service dependencies with protocols.
- Follow Swift API Design Guidelines for naming.
- Keep views thin — no business logic in SwiftUI view bodies.

## Skills

Use these skills (in [`../.claude/skills/`](../.claude/skills/)) for iOS work:

- `spotique-brand-ui` — colors, typography, spacing for any screen or component
- `liquid-glass-design` — iOS 26 Liquid Glass for navigation, toolbars, and floating map controls
- `swift-concurrency-6-2` — Swift 6.2 concurrency patterns (`@MainActor`, `@concurrent`, isolated conformances)
- `swift-actor-persistence` — actor-based file-backed caches (SwiftData remains the default for local persistence)

## Shared API Contract

See [`../docs/api-contract.md`](../docs/api-contract.md) for the REST endpoints this client calls.
