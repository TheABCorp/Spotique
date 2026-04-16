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

- **SwiftUI + SwiftData** — The app uses SwiftData for persistence with `@Model` classes and `ModelContainer`/`ModelContext` for data management.
- **Entry point**: `SpotiqueApp.swift` — sets up the `ModelContainer` with the schema and injects it via `.modelContainer()`.
- **Data models**: Defined in `Spotique/` as `@Model` classes (currently `Item`).
- **Views**: SwiftUI views in `Spotique/` using `@Query` for reactive data fetching and `@Environment(\.modelContext)` for writes.
- **Tests**: Unit tests use Swift Testing framework (`import Testing`, `@Test`). UI tests use XCTest/XCUIApplication.
