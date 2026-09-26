# CLAUDE.md — Web (Rails API)

This file provides guidance to Claude Code when working in the Web directory.

## Project Overview

Spotique Rails API backend — API-only mode, PostgreSQL, Rails 8.1. Serves all mobile clients. No HTML views.

## Build & Test Commands

```bash
# Install dependencies
bundle install

# Start dev server
bin/rails server

# Run full test suite
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/requests/listings_spec.rb

# Run a single example
bundle exec rspec spec/requests/listings_spec.rb:42

# Database
bin/rails db:create db:migrate
bin/rails db:seed

# Lint
bin/rubocop
bin/rubocop -a   # auto-correct
```

## Architecture

- **Rails API-only** — No views, no asset pipeline. JSON responses only.
- **PostgreSQL** — Primary database.
- **Firebase Admin SDK** — Verify phone-auth ID tokens on every authenticated request. No session cookies.
- **Solid Queue** — Background jobs (Rails 8 default).
- **Solid Cache** — Caching (Rails 8 default).

## API Conventions

- Versioned endpoints: `/api/v1/...`
- JSON responses with consistent envelope: `{ "data": ..., "meta": ... }` for collections, `{ "data": ... }` for singles.
- HTTP status codes: 200 OK, 201 Created, 204 No Content, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 422 Unprocessable Entity.
- Pagination via `page` and `per_page` query params; include `meta.pagination` in response.
- Use `before_action` for Firebase token verification on protected routes.

## Conventions

- Write request specs (`spec/requests/`) for every endpoint. Model specs for validations and scopes.
- Use service objects for complex business logic (e.g., booking acceptance flow).
- Follow Rubocop rules in `.rubocop.yml`.
- Keep controllers thin — delegate to models and service objects.
- Use strong parameters. Never trust client input.
- Secrets via Rails credentials (`bin/rails credentials:edit`).

## Shared API Contract

See [`../docs/api-contract.md`](../docs/api-contract.md) for the full endpoint specification.
