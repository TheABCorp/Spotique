# CLAUDE.md — Android

This file provides guidance to Claude Code when working in the Android directory.

## Project Overview

Spotique Android client — Kotlin + Jetpack Compose. Targets API 26+ (Android 8.0), compile SDK 35.

## Build & Test Commands

```bash
# Build debug APK
./gradlew assembleDebug

# Run unit tests
./gradlew test

# Run a single test class
./gradlew test --tests "com.spotique.ExampleTest"

# Run instrumented tests
./gradlew connectedAndroidTest

# Lint
./gradlew ktlintCheck
```

## Architecture

- **MVVM** — Compose UI → ViewModel → Repository → Data Source
- **Jetpack Compose** — All UI is declarative Compose; no XML layouts.
- **Hilt** — Dependency injection for ViewModels, repositories, and data sources.
- **Kotlin Coroutines + Flow** — All async work uses coroutines. Expose UI state as `StateFlow`.
- **Retrofit + OkHttp** — HTTP client for the Rails API backend.
- **Room** — Local persistence / offline caching where needed.

## Key Dependencies

- **Firebase Auth** — Phone-number SMS verification (the only auth method)
- **Cloud Firestore** — Remote data store for listings, bookings, ratings, user profiles
- **Google Maps SDK for Android** — Map view and address autocomplete (scoped to Jackson Heights 11372)
- **FCM** — Push notifications for booking lifecycle events

## Conventions

- Use `StateFlow` (not `LiveData`) to expose UI state from ViewModels.
- ViewModels should use `viewModelScope` for coroutine launches.
- Write unit tests for every ViewModel using JUnit 5 + MockK.
- Follow ktlint for code style (no wildcard imports, standard Kotlin naming).
- Navigation uses Compose Navigation with type-safe routes.
- Keep Compose functions small and preview-friendly (`@Preview`).

## Shared API Contract

See [`../docs/api-contract.md`](../docs/api-contract.md) for the REST endpoints this client calls.
