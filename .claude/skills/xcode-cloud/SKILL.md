---
name: xcode-cloud
description: Set up and maintain Xcode Cloud CI/CD for the Spotique iOS app — workflows, tests, TestFlight distribution, custom build scripts, secrets, and App Store Connect integration.
argument-hint: "[workflow-or-task]"
---

# Skill: Xcode Cloud (Spotique iOS)

Use when configuring or troubleshooting CI/CD for `iOS/`. Xcode Cloud workflows are created and edited in Xcode / App Store Connect (they are not stored as files in the repo), so this skill produces **step-by-step configuration guidance, repo-side scripts, and a written workflow spec** rather than a config file.

## Project Facts

- Project: `iOS/Spotique.xcodeproj`, scheme `Spotique`, bundle ID `com.actionman.Spotique`, iOS 26.1.
- Tests: Swift Testing unit tests (`SpotiqueTests`) and XCUITest (`SpotiqueUITests`).
- Dependencies that affect CI: Firebase, Google Maps SDK (need `GoogleService-Info.plist` and a Maps API key at build time — see Secrets).
- The repo is a monorepo (`iOS/`, `Api/`, `Android/`). Workflows should only start on iOS-relevant changes.

## Recommended Workflows

| Workflow | Trigger | Actions |
|----------|---------|---------|
| **PR Checks** | Pull request targeting `main`, file changes under `iOS/` | Build + unit tests on the current simulator |
| **Main CI** | Push to `main` (`iOS/` changes) | Build, unit + UI tests, upload results |
| **TestFlight Beta** | Push to `main` or a `ios-v*` tag | Test, Archive (iOS), distribute to an internal TestFlight group |
| **Release** | Tag `ios-release-*` (manual approval) | Archive, external TestFlight / App Store submission |

Use start conditions with file/folder filters so Rails-only changes don't burn build minutes. Name workflows descriptively.

## Repo-Side Scripts

Xcode Cloud runs these from `iOS/ci_scripts/` (executable, named exactly):

- `ci_post_clone.sh` — runs after clone; install/resolve tooling, generate ignored config files from secrets.
- `ci_pre_xcodebuild.sh` — runs before each build/test action.
- `ci_post_xcodebuild.sh` — runs after; e.g. notifications or artifact handling.

Keep scripts small, `set -euo pipefail`, and idempotent. Never echo secrets.

## Secrets

- Define secrets as **environment variables marked secret** in the workflow. Never commit them.
- Materialize files at build time in `ci_post_clone.sh`, e.g. write `GoogleService-Info.plist` from a base64 secret into `iOS/Spotique/`, and inject the Maps key via an `.xcconfig` generated from an env var.
- Use separate Firebase/Maps configs (and bundle suffix if needed) for dev/beta versus production.

## Build & Signing

- Use automatic signing managed by Xcode Cloud (App Store Connect access required for the repo integration).
- Build number: Xcode Cloud provides `CI_BUILD_NUMBER`; set `CURRENT_PROJECT_VERSION` from it in `ci_pre_xcodebuild.sh` rather than committing bumps.
- Pin the Xcode version to one that supports the iOS 26.1 SDK; update deliberately.

## Testing in CI

- Unit tests always run; UI tests on main/beta workflows. Use a fixed simulator (e.g. iPhone 16 to match `iOS/CLAUDE.md`).
- Tests must be hermetic — stub the network; no dependence on the live API or real SMS verification.
- Quarantine or fix flaky tests promptly; don't blanket-retry.
- Enable code coverage collection and review the trend.

## Distribution

- Internal TestFlight group: automatic on TestFlight Beta workflow.
- Include "What to Test" notes from commit messages or a checked-in `TESTFLIGHT_NOTES` file.
- App Store submission stays a manual, reviewed step until the MVP has shipped.

## Local Verification

Before relying on CI, confirm locally with the `xcodebuild` build/test commands in `iOS/CLAUDE.md`. CI failures reproduce most reliably with the same scheme, destination, and Xcode version.

## Troubleshooting

- **Missing plist / key**: check secret env var names and `ci_post_clone.sh` output.
- **Package resolution fails**: check package access and pinned versions in `Package.resolved` (commit it).
- **Signing errors**: verify the App Store Connect integration, bundle ID registration, and capabilities (Push Notifications) on the App ID.
- **Works locally, fails in CI**: mismatched Xcode/simulator versions or files ignored by git.

## Output

Deliver: the workflow specification (name, trigger, filters, actions, env vars), any scripts added under `iOS/ci_scripts/`, and the exact manual steps needed in Xcode/App Store Connect.
