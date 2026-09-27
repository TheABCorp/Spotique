---
name: ios-debugging
description: Systematically debug Spotique iOS issues — crashes, concurrency/actor errors, SwiftUI state bugs, memory leaks, networking, push, and Firebase/Google Maps problems — using LLDB, Xcode, and Instruments.
argument-hint: "[symptom-or-crash-log]"
---

# Skill: iOS Debugging (Spotique)

Use when something in `iOS/` crashes, misbehaves, or hangs. Find the root cause before changing code.

## Method

1. **Reproduce** — get exact steps, iOS version, device vs simulator, build config. If it can't be reproduced, gather logs before theorizing.
2. **Read the evidence** — crash log/stack trace, console output, compiler diagnostics. Identify the top app frame and the exception/signal type.
3. **Form a hypothesis** and find the cheapest way to test it (a breakpoint, a log, a failing unit test).
4. **Narrow** — bisect by disabling code paths, checking recent commits (`git log`, `git bisect`), or isolating in a unit test.
5. **Fix the root cause**, not the symptom. Add a regression test where feasible.
6. **Verify** — rerun the repro, run the test suite, and check for side effects.

Build and test with the commands in `iOS/CLAUDE.md`.

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| `EXC_BAD_ACCESS` | Unsafe/unowned reference, C/ObjC interop (Google Maps SDK) | Zombies + Address Sanitizer |
| `Fatal error: Unexpectedly found nil` | Force unwrap, missing decoded field | Decoder + contract fixture |
| `SIGABRT` with `NSException` | Bad SDK config (missing `GoogleService-Info.plist`, Maps key), invalid constraint/state | Console message above the trace |
| "Data race" / actor-isolation errors | Crossing isolation without `Sendable`, `@MainActor` gaps | Thread Sanitizer; see `swift-concurrency-6-2` |
| UI not updating | Mutating a non-observed value, wrong `@State`/`@Bindable` ownership, off-main-actor mutation | ViewModel `@Observable`/`@MainActor` |
| View resets state | Unstable identity, view recreated by parent | `id`s, `Self._printChanges()` in `body` |
| Leak / growing memory | Retain cycle in closures, observers, map wrapper delegates | Memory Graph Debugger, Leaks |
| Watchdog / frozen UI | Blocking work on main actor | Time Profiler (`ios-performance`) |
| Decode failure | Server shape ≠ model | Compare with `docs/api-contract.md`; log the raw body in debug only |
| Auth failures | Expired/absent Firebase ID token, SMS verification setup | Firebase console, token refresh path |
| Missing pushes | APNs entitlement/provisioning, device token not registered, foreground handling | Push capability, `UNUserNotificationCenterDelegate`, device (not simulator) |
| SwiftData crash / migration | Schema changed without migration | `ModelContainer` setup in `SpotiqueApp.swift` |

## Tools

- **LLDB**: `po`, `p`, `bt`, `frame variable`, `thread backtrace all`, `expr` to poke at state; symbolic breakpoints on `swift_willThrow` and `UIViewAlertForUnsatisfiableConstraints`.
- **Xcode**: View Debugger, Memory Graph, Debug Navigator, runtime issue navigator, Thread/Address Sanitizers (scheme diagnostics).
- **Instruments**: Time Profiler, Allocations, Leaks, Network, Energy Log.
- **Console**: filter with `os.Logger` subsystem/category. Use `Logger`, not `print`, for anything that might ship.
- **Symbolication**: for a crash log from TestFlight/Xcode Cloud, use Xcode's Organizer with the matching build's dSYMs.

## Logging Rules

- Use `os.Logger` with privacy annotations. Never log tokens, verification codes, phone numbers, or full street addresses; mark interpolations `.private`.
- Debug-only logging of raw network bodies must be compiled out of release builds.

## Output

When reporting a diagnosis, state: the symptom, the root cause with `file:line`, the evidence that confirms it, the fix, and how it was verified.
