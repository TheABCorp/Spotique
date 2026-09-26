---
name: rails-schema-design
description: Design normalized relational schemas for this Rails app. Use when adding or changing tables, columns, associations, or migrations, or when asked to model a new domain concept. Produces a reviewed data model, then migrations and model associations.
---

# Rails schema design

Design the data model before writing any migration. The database, not ActiveRecord, is the last line of defense for data integrity.

## Workflow

1. **Understand the domain.** List the entities, their attributes, and how they relate (1:1, 1:N, M:N). Read `db/schema.rb` (or `db/structure.sql`) and the relevant models first so new tables fit what exists. Reuse existing tables before creating new ones.
2. **Normalize to 3NF.** Check each proposed table:
   - 1NF: no repeating groups or comma-separated lists in a column; no `tag1`, `tag2` columns. Use a child table.
   - 2NF: every non-key column depends on the whole key (matters for composite keys and join tables).
   - 3NF: no column depends on another non-key column. If `orders.customer_email` depends on `customer_id`, it belongs on `customers`.
   - Pull enumerated sets that carry their own attributes or change at runtime into lookup tables; small fixed sets can be Rails `enum` backed by a string or integer column with a CHECK constraint.
3. **Justify any denormalization.** Only denormalize (counter caches, cached totals, snapshot columns) with a stated read-performance reason and a plan for keeping it consistent. Historical snapshots (e.g. price at time of purchase) are not denormalization; they are distinct facts and should be stored.
4. **Audit every column** with the tests in "Column audit" below, and put the result in the review: one line per column saying which table it belongs in and what enforces it.
5. **Present the model for review** before writing code: a table list with columns, types, nullability, keys, indexes, and constraints, plus a short Mermaid `erDiagram`. Call out every denormalization and every open question.
6. **Write migrations and models** once the model is agreed.

## Column audit

Ask these about every column, in order. The first "yes" decides where the column goes.

1. **Is it true of every row, from the moment the row exists?** If yes, it stays here as `null: false`. If no, answer question 2 before allowing NULL.
2. **Why can it be NULL?**
   - *Doesn't apply to some rows* (a pro's rating, which a homeowner doesn't have): it belongs to a subtype or role table, such as `provider_profiles` with `user_id` unique. Nulls that mean "not applicable" point to a missing table.
   - *Not known yet* (filled in at a later step): prefer a separate table whose row is created at that step. Allow NULL here only when the gap is short-lived and the column is plain data about this entity; write down the reason in the review.
   - A column that is NULL for most rows is almost always in the wrong table.
3. **Can there be more than one?** (addresses, phone numbers, payment methods): make it a child table, even if the UI shows one today.
4. **Does it have its own parts or its own lifecycle?** (an address has street/city/postal code and gets verified or geocoded; a payment method expires): make it its own table with typed columns, not one string.
5. **Is it computed from other data?** (counts, percentages, averages, totals): store the facts it comes from (reviews, bookings). A cached copy is allowed only as a labelled denormalization: store the counts, never the ratio (`positive_count` and `rating_count`, not `rating_positive_pct`); give it a CHECK such as `positive_count <= rating_count`; update it in exactly one place; and add a job that recomputes it from the source facts.
6. **Does it describe something other than this entity?** (a role, a relationship, another system's record): it belongs with that thing.
7. **Is it sensitive or owned by an external system?** (payments, identity documents): store the provider's reference ID (`stripe_customer_id`, `stripe_payment_method_id`) plus safe display fields (brand, last4, exp), never free text.
8. **Is it a fixed set of values?** Use `null: false` with a CHECK constraint or a lookup table. A nullable, unchecked `string` role column accepts anything.
9. **Does its format matter?** Enforce it in the database: `citext` for emails (or a unique index on `lower(email)`), a CHECK for E.164 phone numbers, CHECK ranges for counts and percentages.

A core entity table such as `users` should hold only its identity and the attributes every row has. Put role-specific data, contact channels, addresses, payment data and derived metrics in their own tables, linked by foreign keys.

## Table and column conventions

- Plural snake_case table names; `bigint` primary key `id` (Rails default) unless the repo already uses UUIDs, in which case match it.
- Foreign keys: `t.references :customer, null: false, foreign_key: true` creates the column, index, and FK constraint together. Set `on_delete:` deliberately (`:cascade` for owned children, `:restrict`/default for referenced records, `:nullify` only when the relationship is truly optional).
- `null: false` on every column that is required. Add defaults where a sensible one exists.
- Money: `decimal(precision: 12, scale: 2)` or integer cents; never float.
- Timestamps: always `t.timestamps`. Use `datetime` (timestamptz in Postgres) for instants, `date` for calendar dates.
- Strings: `string` for short bounded values, `text` for free text. Use `citext` or a lowercased unique index for case-insensitive uniqueness such as emails.
- Avoid JSON/JSONB for data you query, join, or validate on. It is fine for opaque payloads (webhook bodies, third-party responses).

## Constraints belong in the database

Every rule an ActiveRecord validation enforces should also be enforced by the database where possible, because validations are skipped by `update_column`, `insert_all`, raw SQL, and race conditions.

| Rule | Model | Database |
|---|---|---|
| Required | `validates :x, presence: true` / `belongs_to` | `null: false` |
| Unique | `validates :x, uniqueness: true` | `add_index ..., unique: true` |
| Scoped unique | `uniqueness: { scope: :account_id }` | composite unique index |
| Valid values | `enum` / `inclusion` | `add_check_constraint` |
| Referential integrity | `belongs_to` | `foreign_key: true` |

## Associations

- **M:N:** use a real join model with `has_many :through`, not `has_and_belongs_to_many`. Give the join table a unique composite index on the two FKs, and put relationship attributes (role, position, joined_at) on it.
- **Polymorphic associations** can't have FK constraints. Prefer separate nullable FKs with a CHECK that exactly one is set, or separate join tables, unless the set of parent types is genuinely open-ended.
- **Single-table inheritance** only when subtypes share nearly all columns; otherwise use separate tables or delegated types (`delegated_type`).
- Set `dependent:` on every `has_many`/`has_one`, and keep it consistent with the FK's `on_delete`.
- Add `inverse_of` where Rails can't infer it.

## Indexes

- Every foreign key is indexed (`t.references` does this).
- Add indexes for columns used in `where`, `order`, and uniqueness checks. For composite indexes, put the equality-filtered column first.
- Use partial indexes for common filtered queries (e.g. `where: "deleted_at IS NULL"`) and partial unique indexes for rules like "one active subscription per account".
- Don't add indexes speculatively on low-selectivity columns.

## Migrations

- One logical change per migration; keep them reversible (`change`, or `up`/`down` when Rails can't infer the reverse).
- On large or busy tables: add indexes with `algorithm: :concurrently` and `disable_ddl_transaction!`; add FKs with `validate: false` then validate in a separate migration; add NOT NULL via a validated CHECK constraint first, then `change_column_null`.
- Never rename or drop a column in one step on a live table. Add the new column, backfill, switch reads/writes, then remove the old one with `ignored_columns` set first.
- Backfill data in a separate migration or task, in batches (`in_batches`), not inside a schema migration.

## Output checklist

Before finishing, confirm:
- [ ] Tables reach 3NF, and any denormalization is justified in writing
- [ ] Every required column is `null: false`
- [ ] Every FK has a constraint and an index
- [ ] Every uniqueness rule has a unique index
- [ ] Enumerated values have a CHECK constraint or lookup table
- [ ] Model validations and associations mirror the DB constraints
- [ ] Migrations are reversible and safe for the table's size
- [ ] `db/schema.rb` is regenerated and the test suite runs
