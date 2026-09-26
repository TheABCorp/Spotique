# Multi-Agent Development Guide

This repo supports parallel development across iOS, Android, and Web using separate Claude Code agents.

## Workflow: API First, Then Clients

1. **API agent** — Implement the Rails endpoint in `Web/`. Follow `Web/CLAUDE.md`. Write request specs.
2. **iOS agent** — Implement the client feature in `iOS/`. Follow `iOS/CLAUDE.md`. Write ViewModel tests.
3. **Android agent** — Implement the client feature in `Android/`. Follow `Android/CLAUDE.md`. Write ViewModel tests.

Steps 2 and 3 run in parallel after step 1 is done.

## Running Parallel Agents

Use Claude Code's Task tool to launch one agent per platform:

```
Launch three agents in parallel:
- Agent 1: "Implement POST /bookings endpoint in Web/ per docs/api-contract.md and Web/CLAUDE.md"
- Agent 2: "Implement booking request screen in iOS/ calling POST /bookings per docs/api-contract.md and iOS/CLAUDE.md"
- Agent 3: "Implement booking request screen in Android/ calling POST /bookings per docs/api-contract.md and Android/CLAUDE.md"
```

## Shared References

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project-wide context (product facts, platforms, integrations) |
| `docs/api-contract.md` | REST endpoint specs — the single source of truth for request/response shapes |
| `iOS/CLAUDE.md` | iOS build commands, architecture, conventions |
| `Android/CLAUDE.md` | Android build commands, architecture, conventions |
| `Web/CLAUDE.md` | Rails build commands, architecture, conventions |

## Rules for Agents

- **Always read the API contract** (`docs/api-contract.md`) before implementing any endpoint or client call.
- **Never duplicate data models** — derive request/response types from the contract.
- **Keep platform CLAUDE.md files updated** when you add new dependencies or change conventions.
- **Write tests** at every layer (request specs for API, ViewModel tests for clients).
- **Respect the privacy model** — addresses and phone numbers are only revealed after booking confirmation.

## Feature Development Checklist

For each new feature:

- [ ] Define or verify the endpoint in `docs/api-contract.md`
- [ ] Implement the Rails endpoint with request specs
- [ ] Implement iOS client with ViewModel tests
- [ ] Implement Android client with ViewModel tests
- [ ] Verify consistent behavior across platforms
