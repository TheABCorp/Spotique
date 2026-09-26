# Skill: Rails API Endpoint

Build an API endpoint for the Spotique Rails backend.

## Before You Start

1. Read `Api/CLAUDE.md` for build commands, architecture, and conventions.
2. Read `docs/api-contract.md` for the endpoint specification.
3. Review existing controllers in `Api/app/controllers/api/v1/`.

## Architecture

- **Rails API-only** — No views. JSON responses only.
- **Versioned routes** — All endpoints under `/api/v1/`.
- **Firebase Admin SDK** — Verify ID tokens in a `before_action`. No session cookies.
- **Service objects** — Complex business logic (e.g., booking acceptance) goes in `app/services/`.

## Implementation Steps

1. **Generate the model** (if new) — `bin/rails generate model Listing address:string latitude:float ...`. Add validations, scopes, and associations.
2. **Write the migration** — Ensure proper indexes (especially on `user_id`, geospatial columns, `status`).
3. **Create the controller** — `Api::V1::ListingsController`. Inherit from `ApplicationController`. Use strong parameters.
4. **Add the route** — In `config/routes.rb` under `namespace :api { namespace :v1 { ... } }`.
5. **Add Firebase auth** — `before_action :authenticate_user!` that verifies the `Authorization: Bearer <token>` header.
6. **Write request specs** — `spec/requests/api/v1/listings_spec.rb`. Test happy path, auth failures, validation errors, 404s.

## Response Format

```ruby
# Collection
render json: { data: listings, meta: { pagination: { page:, per_page:, total: } } }

# Single resource
render json: { data: listing }

# Error
render json: { error: { code: "validation_failed", message: "...", details: errors } }, status: :unprocessable_entity
```

## Constraints

- MVP geography: Jackson Heights, Queens, NY (zip 11372). Validate listing addresses are in this area.
- Privacy: Never return `address` or `host_phone` unless the requester has a confirmed booking for that listing.
- Auth: Every endpoint except `POST /auth/verify` requires a valid Firebase ID token.
- Payments: Off-platform. No payment models or endpoints.

## Conventions

- Controllers: thin. Delegate to models/services.
- Models: validations, scopes, associations. No business logic callbacks.
- Services: `app/services/` for multi-step operations. Return result objects.
- Tests: request specs are mandatory. Model specs for validations and scopes.
- Use Rubocop. Run `bin/rubocop` before committing.
