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

ActiveRecord::Schema[8.0].define(version: 2025_08_13_140042) do
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
    t.uuid "agency_plan_id"
    t.index ["agency_plan_id"], name: "index_agencies_on_agency_plan_id"
    t.index ["created_by_id"], name: "index_agencies_on_created_by_id"
    t.index ["custom_domain"], name: "index_agencies_on_custom_domain", unique: true
    t.index ["slug"], name: "index_agencies_on_slug", unique: true
  end

  create_table "agency_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "max_employees", default: 1, null: false
    t.integer "max_properties", default: 10, null: false
    t.integer "max_photos", default: 5, null: false
    t.integer "max_buy_requests", default: 50, null: false
    t.integer "max_sell_requests", default: 10, null: false
    t.boolean "is_custom", default: false, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_default", default: false, null: false
    t.index ["is_default"], name: "index_agency_plans_on_is_default"
    t.index ["title"], name: "index_agency_plans_on_title", unique: true
  end

  create_table "agency_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.string "logo_url"
    t.string "color_scheme"
    t.string "locale"
    t.string "timezone"
    t.jsonb "site_title", default: {}, null: false
    t.jsonb "site_description", default: {}
    t.jsonb "home_page_content", default: {}
    t.jsonb "contacts_page_content", default: {}
    t.jsonb "meta_keywords", default: {}
    t.jsonb "meta_description", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_agency_settings_on_agency_id", unique: true
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.uuid "person_id", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.string "middle_name"
    t.string "email"
    t.string "extra_phones", default: [], null: false, array: true
    t.text "notes"
    t.boolean "is_deleted", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "person_id"], name: "index_contacts_on_agency_and_person", unique: true
    t.index ["agency_id"], name: "index_contacts_on_agency_id"
    t.index ["person_id"], name: "index_contacts_on_person_id"
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

  create_table "customers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.uuid "user_id"
    t.integer "service_type", default: 0, null: false
    t.text "notes"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "contact_id", null: false
    t.index ["agency_id"], name: "index_customers_on_agency_id"
    t.index ["contact_id"], name: "index_customers_on_contact_id"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "mobility_string_translations", force: :cascade do |t|
    t.string "locale", null: false
    t.string "key", null: false
    t.string "value"
    t.string "translatable_type"
    t.bigint "translatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_string_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_string_translations_on_keys", unique: true
    t.index ["translatable_type", "key", "value", "locale"], name: "index_mobility_string_translations_on_query_keys"
  end

  create_table "mobility_text_translations", force: :cascade do |t|
    t.string "locale", null: false
    t.string "key", null: false
    t.text "value"
    t.string "translatable_type"
    t.bigint "translatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_text_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_text_translations_on_keys", unique: true
  end

  create_table "people", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "normalized_phone", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "blocked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_phone"], name: "index_people_on_normalized_phone", unique: true
  end

  create_table "properties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.decimal "price", precision: 12, scale: 2, null: false
    t.decimal "discount", default: "0.0"
    t.integer "listing_type", null: false
    t.integer "status", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "deleted_at"
    t.uuid "category_id", null: false
    t.uuid "agent_id", null: false
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_properties_on_agency_id"
    t.index ["agent_id"], name: "index_properties_on_agent_id"
    t.index ["category_id"], name: "index_properties_on_category_id"
    t.index ["is_active"], name: "index_properties_on_is_active"
  end

  create_table "property_buy_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.uuid "agency_id", null: false
    t.uuid "user_id"
    t.text "comment"
    t.text "response_message"
    t.integer "status", default: 0, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "customer_id"
    t.uuid "contact_id", null: false
    t.index ["agency_id", "status"], name: "index_property_buy_requests_on_agency_id_and_status"
    t.index ["agency_id"], name: "index_property_buy_requests_on_agency_id"
    t.index ["contact_id"], name: "index_property_buy_requests_on_contact_id"
    t.index ["customer_id"], name: "index_property_buy_requests_on_customer_id"
    t.index ["property_id", "is_deleted"], name: "index_property_buy_requests_on_property_id_and_is_deleted"
    t.index ["property_id"], name: "index_property_buy_requests_on_property_id"
    t.index ["user_id"], name: "index_property_buy_requests_on_user_id"
  end

  create_table "property_categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.integer "position"
    t.boolean "is_active", default: true, null: false
    t.uuid "parent_id"
    t.integer "level", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id", "slug"], name: "index_property_categories_on_agency_id_and_slug", unique: true
    t.index ["agency_id"], name: "index_property_categories_on_agency_id"
    t.index ["parent_id"], name: "index_property_categories_on_parent_id"
  end

  create_table "property_category_characteristics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_category_id", null: false
    t.uuid "property_characteristic_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_category_id", "property_characteristic_id"], name: "index_category_characteristics_uniqueness", unique: true
    t.index ["property_category_id"], name: "idx_on_property_category_id_27d01bf010"
    t.index ["property_characteristic_id"], name: "idx_on_property_characteristic_id_cdaa3e88f5"
  end

  create_table "property_characteristic_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_characteristic_id", null: false
    t.string "value", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_characteristic_id", "value"], name: "index_characteristic_options_uniqueness", unique: true
    t.index ["property_characteristic_id"], name: "idx_on_property_characteristic_id_c6d3169322"
  end

  create_table "property_characteristic_values", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.uuid "property_characteristic_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_characteristic_id"], name: "idx_on_property_characteristic_id_1ac02bdeb2"
    t.index ["property_id", "property_characteristic_id"], name: "index_characteristic_values_uniqueness", unique: true
    t.index ["property_id"], name: "index_property_characteristic_values_on_property_id"
  end

  create_table "property_characteristics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.string "title", null: false
    t.string "unit"
    t.string "field_type", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_private", default: false, null: false
    t.index ["agency_id", "title"], name: "index_property_characteristics_on_agency_id_and_title", unique: true
    t.index ["agency_id"], name: "index_property_characteristics_on_agency_id"
  end

  create_table "property_comments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.uuid "user_id", null: false
    t.text "body", null: false
    t.boolean "edited", default: false, null: false
    t.datetime "edited_at"
    t.integer "edit_count", default: 0, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id", "is_deleted"], name: "index_property_comments_on_property_id_and_is_deleted"
    t.index ["property_id"], name: "index_property_comments_on_property_id"
    t.index ["user_id"], name: "index_property_comments_on_user_id"
  end

  create_table "property_locations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.string "country", null: false
    t.string "region", null: false
    t.string "city", null: false
    t.string "street", null: false
    t.string "house_number", null: false
    t.string "map_link"
    t.boolean "is_info_hidden", default: true, null: false
    t.string "country_code"
    t.string "region_code"
    t.string "city_code"
    t.uuid "geo_city_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_property_locations_on_property_id"
  end

  create_table "property_owners", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.uuid "user_id"
    t.text "notes"
    t.integer "role", default: 0, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "contact_id", null: false
    t.index ["contact_id"], name: "index_property_owners_on_contact_id"
    t.index ["property_id", "is_deleted"], name: "index_property_owners_on_property_id_and_is_deleted"
    t.index ["property_id"], name: "index_property_owners_on_property_id"
    t.index ["user_id"], name: "index_property_owners_on_user_id"
  end

  create_table "property_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "property_id", null: false
    t.string "file_url", null: false
    t.string "file_preview_url"
    t.string "file_retina_url"
    t.boolean "is_main", default: false, null: false
    t.integer "position", default: 1, null: false
    t.string "access", default: "public", null: false
    t.uuid "uploaded_by_id", null: false
    t.uuid "agency_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id", "is_main"], name: "index_property_photos_on_property_id_main", unique: true, where: "(is_main = true)"
    t.index ["property_id"], name: "index_property_photos_on_property_id"
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
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 5, null: false
    t.string "country_code", default: "RU", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "last_sign_in_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "person_id", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["person_id"], name: "index_users_on_person_id", unique: true
  end

  add_foreign_key "agencies", "agency_plans"
  add_foreign_key "agencies", "users", column: "created_by_id"
  add_foreign_key "agency_settings", "agencies"
  add_foreign_key "contacts", "agencies"
  add_foreign_key "contacts", "people"
  add_foreign_key "customers", "agencies"
  add_foreign_key "customers", "contacts"
  add_foreign_key "customers", "users"
  add_foreign_key "property_buy_requests", "agencies"
  add_foreign_key "property_buy_requests", "contacts"
  add_foreign_key "property_buy_requests", "customers"
  add_foreign_key "property_buy_requests", "properties"
  add_foreign_key "property_buy_requests", "users"
  add_foreign_key "property_categories", "agencies"
  add_foreign_key "property_categories", "property_categories", column: "parent_id"
  add_foreign_key "property_category_characteristics", "property_categories"
  add_foreign_key "property_category_characteristics", "property_characteristics"
  add_foreign_key "property_characteristic_options", "property_characteristics"
  add_foreign_key "property_characteristic_values", "properties"
  add_foreign_key "property_characteristic_values", "property_characteristics"
  add_foreign_key "property_characteristics", "agencies"
  add_foreign_key "property_comments", "properties"
  add_foreign_key "property_comments", "users"
  add_foreign_key "property_locations", "properties"
  add_foreign_key "property_owners", "contacts"
  add_foreign_key "property_owners", "properties"
  add_foreign_key "property_owners", "users"
  add_foreign_key "property_photos", "properties"
  add_foreign_key "user_agencies", "agencies"
  add_foreign_key "user_agencies", "users"
  add_foreign_key "users", "people"
end
