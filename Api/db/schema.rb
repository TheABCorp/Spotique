# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_26_000008) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "addresses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "label"
    t.string "street", null: false
    t.string "city", null: false
    t.string "state", null: false
    t.string "zip", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
    t.check_constraint "label::text = ANY (ARRAY['home'::character varying, 'work'::character varying, 'other'::character varying]::text[])", name: "addresses_label_valid"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "phone"
    t.citext "email"
    t.string "first_name"
    t.string "last_name"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["phone"], name: "index_users_on_phone", unique: true, where: "(phone IS NOT NULL)"
    t.check_constraint "phone IS NOT NULL OR email IS NOT NULL", name: "users_phone_or_email_present"
    t.check_constraint "phone::text ~ '^\\+1\\d{10}$'::text", name: "users_phone_e164_format"
    t.check_constraint "role::text = ANY (ARRAY['host'::character varying, 'driver'::character varying, 'both'::character varying]::text[])", name: "users_role_valid"
  end

  create_table "verification_codes", force: :cascade do |t|
    t.string "phone"
    t.citext "email"
    t.string "code_digest", null: false
    t.datetime "expires_at", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.index ["email", "created_at"], name: "index_verification_codes_on_email_and_created_at", where: "(email IS NOT NULL)"
    t.index ["phone", "created_at"], name: "index_verification_codes_on_phone_and_created_at", where: "(phone IS NOT NULL)"
    t.check_constraint "phone IS NOT NULL OR email IS NOT NULL", name: "verification_codes_phone_or_email_present"
    t.check_constraint "phone::text ~ '^\\+1\\d{10}$'::text", name: "verification_codes_phone_e164_format"
  end

  add_foreign_key "addresses", "users", on_delete: :cascade
end
