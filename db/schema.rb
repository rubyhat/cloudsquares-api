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

ActiveRecord::Schema[8.0].define(version: 2025_06_12_212253) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agencies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.string "custom_domain"
    t.boolean "is_blocked", default: false, null: false
    t.datetime "blocked_at"
    t.boolean "is_active", default: true, null: false
    t.datetime "deleted_at"
    t.uuid "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_agencies_on_created_by_id"
    t.index ["custom_domain"], name: "index_agencies_on_custom_domain", unique: true
    t.index ["slug"], name: "index_agencies_on_slug", unique: true
  end

  create_table "countries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "code", null: false
    t.text "phone_prefixes", default: [], null: false, array: true
    t.boolean "is_active", default: true, null: false
    t.string "locale"
    t.string "timezone"
    t.integer "position"
    t.string "default_currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
    t.index ["title"], name: "index_countries_on_title", unique: true
  end

  create_table "user_agencies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "agency_id", null: false
    t.string "status", default: "active", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "joined_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "left_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_user_agencies_on_agency_id"
    t.index ["user_id", "agency_id"], name: "index_user_agencies_on_user_id_and_agency_id", unique: true
    t.index ["user_id"], name: "index_user_agencies_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "phone", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.string "middle_name"
    t.integer "role", default: 5, null: false
    t.string "country_code", default: "RU", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "last_sign_in_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true
  end

  add_foreign_key "agencies", "users", column: "created_by_id"
  add_foreign_key "user_agencies", "agencies"
  add_foreign_key "user_agencies", "users"
end
