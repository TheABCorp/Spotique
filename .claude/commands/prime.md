---
description: Prime the agent with Spotique project context — read the docs, platform guides, and key code, check repo state, and summarize. Run at the start of a session before planning or implementing.
argument-hint: "[platform: api | ios | android | all]"
---

# Prime: Load Spotique Project Context

## Objective

Build a working understanding of the Spotique codebase before doing any planning or implementation. This skill is read-only: **do not modify files.**

Scope: `$ARGUMENTS` — one of `api`, `ios`, `android`, or `all`. If empty, prime for the whole repo at a high level and go deep only on the platform(s) with recent activity.

## Process

### 1. Repo State

Current branch and working tree:
!`git status --short --branch`

Recent history:
!`git log -10 --oneline`

Top-level layout (two levels deep, tracked files only):
!`git ls-files | awk -F/ '{ if (NF>1) print $1"/"$2; else print $1 }' | sort -u | head -150`

If the branch is `main`, note it — new work must start on a new branch (see CLAUDE.md "Branching").

### 2. Product & Project Docs

Read, in this order:

1. `CLAUDE.md` — product facts, privacy and trust model, platform map, commit rules
2. `docs/prd-v1.md` — scope, personas, feature requirements (P0/P1), non-functional requirements, open questions
3. `docs/api-contract.md` — endpoints and shapes (the source of truth for clients)
4. `docs/specs/` and `docs/plans/` (if present) — list them and read any relevant to current work
5. `.claude/agents.md` — multi-agent workflow (API first, then clients)

### 3. Platform Guides and Key Code

For each in-scope platform, read its `CLAUDE.md` and `README.md`, then the key files:

- **Api (Rails 8.1, API-only)** — `Api/CLAUDE.md`; `Api/Gemfile`; `Api/config/routes.rb`; `Api/db/schema.rb` (or `structure.sql`); models in `Api/app/models/`; controllers in `Api/app/controllers/`; test layout in `Api/test/` (or `spec/` if present).
- **iOS (SwiftUI + SwiftData, iOS 26.1)** — `iOS/CLAUDE.md`; app entry `iOS/Spotique/SpotiqueApp.swift`; `@Model` types, ViewModels, and services under `iOS/Spotique/`; test layout in `iOS/SpotiqueTests/`.
- **Android (Kotlin + Compose)** — `Android/CLAUDE.md`. Note that it's currently TBD/scaffold-only if there's no code.

Don't read everything. Sample enough files to identify structure, patterns, and conventions, and prefer entry points, configuration, schema, and one representative feature per layer.

### 4. Skills Inventory

List `.claude/skills/` and note which skills are relevant to the in-scope platform(s) (e.g. `rails-api`, `rails-schema-design`, `mvvm-architecture`, `swiftui-development`, `ios-api-client`, `spotique-brand-ui`, `tech-spec`, `plan-feature`, `execute-plan`, `build`). Don't read them all — just know they exist and when to use each.

### 5. Current Focus

From the git log, status, and any in-progress specs or plans, work out what's being built right now and what's stalled or unfinished.

## Output Report

Make it easy to scan — bullets and short headers.

### Project Overview
- What Spotique is (hourly private-parking marketplace), MVP geography, and the product rules that shape code: off-platform payments, verified identity, the address/host-phone privacy model, and the rating/no-show trust model

### Architecture
- Repo layout and the purpose of each top-level directory
- Per platform: structure, key patterns (e.g. MVVM with `@Observable` on iOS; Rails API-only), and how they connect via `docs/api-contract.md`

### Tech Stack
- Languages/versions, frameworks, major dependencies (Firebase Auth, Firestore, Google Maps/Places, APNs), build tools, and test frameworks per platform

### Conventions
- Naming, testing approach, commit and branching rules (new branch for new work; no AI attribution in commits or PRs)

### Current State
- Branch, working-tree status, and recent commits
- Implemented vs. planned: which PRD features and endpoints exist, and which specs/plans are pending
- Open questions from the PRD that affect upcoming work

### Observations
- Gaps, inconsistencies (e.g. docs vs. code), or risks worth knowing before starting

Finish with a one-line prompt asking what the user wants to work on next, suggesting `plan-feature` (or `tech-spec`) for a new feature.
