# Spotique API

Rails 8.1 API-only backend for Spotique — an hourly private-parking marketplace.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

That's it. Ruby, PostgreSQL, and all gems run inside containers.

## Quick start

From the `Api/` directory:

```bash
# 1. Build the dev image
docker compose build

# 2. Start Postgres and the Rails server
docker compose up

# 3. (First run) Create and migrate the database
docker compose exec api bin/rails db:create db:migrate
```

The API is now running at **http://localhost:3000**. Verify with:

```bash
curl http://localhost:3000/up
```

## Common tasks

### Run the full test suite

```bash
docker compose run --rm test bin/rails db:create db:migrate test
```

### Run a single test file

```bash
docker compose exec api bin/rails test test/models/user_test.rb
```

### Rails console

```bash
docker compose exec api bin/rails console
```

### Install new gems

After editing `Gemfile`:

```bash
docker compose exec api bundle install
```

Or rebuild the image to bake them in:

```bash
docker compose build api
```

### Database commands

```bash
# Migrate
docker compose exec api bin/rails db:migrate

# Rollback
docker compose exec api bin/rails db:rollback

# Seed
docker compose exec api bin/rails db:seed

# Reset (drop + create + migrate + seed)
docker compose exec api bin/rails db:reset

# Connect to psql
docker compose exec db psql -U spotique spotique_development
```

### Stop everything

```bash
docker compose down       # stop containers
docker compose down -v    # stop and delete database volume
```

## Project structure

```
app/
  controllers/api/v1/   — versioned API controllers
  models/               — ActiveRecord models
  services/             — service objects (SMS, JWT, etc.)
  mailers/              — Action Mailer classes
config/
  routes.rb             — API route definitions
  database.yml          — database config (uses DATABASE_URL in Docker)
db/
  migrate/              — database migrations
test/
  models/               — model unit tests
  integration/          — request/integration tests
```

## Environment variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Set by docker-compose |
| `RAILS_ENV` | Rails environment | `development` |
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` | From `config/master.key` |

Secrets (Twilio, SMTP, JWT) are stored in Rails credentials:

```bash
docker compose exec api bin/rails credentials:edit
```

## Native setup (without Docker)

If you prefer running without Docker, install Ruby 4.0.2 and PostgreSQL 16 locally, then:

```bash
bundle install
bin/rails db:create db:migrate
bin/rails server
```
