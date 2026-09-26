---
name: android-feature
description: Build a feature for the Spotique Android app using Kotlin + Jetpack Compose with MVVM architecture.
---

# Skill: Android Feature

Build a feature for the Spotique Android app.

## Before You Start

1. Read `Android/CLAUDE.md` for build commands, architecture, and conventions.
2. Read `docs/api-contract.md` for the endpoint this feature calls.
3. Understand the existing code structure in `Android/`.

## Architecture

- **MVVM**: Composable (UI) → ViewModel (Hilt-injected) → Repository → Data Source (Retrofit/Firestore).
- **Jetpack Compose** for all UI. No XML layouts.
- **Hilt** for dependency injection.
- **Kotlin Coroutines + Flow** for async work. Expose state as `StateFlow`.

## Implementation Steps

1. **Define the data class** — Kotlin data class matching `docs/api-contract.md` field names. Add Gson/Moshi annotations if needed.
2. **Create the API interface** — Retrofit `@GET`/`@POST`/etc. methods returning `Response<T>`.
3. **Create the repository** — Inject the API interface. Return `Flow` or suspend functions. Handle errors.
4. **Create the ViewModel** — `@HiltViewModel class`. Use `viewModelScope` for coroutine launches. Expose `StateFlow<UiState>`.
5. **Build the Composable** — Collect state with `collectAsStateWithLifecycle()`. Keep composables small and previewable.
6. **Write tests** — JUnit 5 + MockK for ViewModel tests. Test state transitions, error handling, edge cases.

## Key Dependencies

- **Firebase Auth** — Phone-number verification. Access via `Firebase.auth.currentUser`.
- **Cloud Firestore** — `com.google.firebase:firebase-firestore-ktx`.
- **Google Maps SDK** — Maps Compose library. Scope to Jackson Heights 11372.
- **Retrofit + OkHttp** — HTTP client with Firebase token interceptor.

## Constraints

- MVP geography: Jackson Heights, Queens, NY (zip 11372).
- Privacy: Never show full address or host phone until booking is confirmed.
- Auth: Phone-number only. Always check `Firebase.auth.currentUser` before protected actions.
- Payments: Off-platform (cash/Venmo/Zelle). No payment UI needed.

## Naming Conventions

- Classes: `UpperCamelCase` (e.g., `ListingViewModel`, `BookingRepository`)
- Functions/properties: `lowerCamelCase`
- Packages: `com.spotique.feature.<name>`
- Test classes: `ListingViewModelTest`
