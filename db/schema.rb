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

ActiveRecord::Schema[8.1].define(version: 2026_10_04_035718) do
  create_table "provider_taxonomies", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "code", null: false
    t.index ["code"], name: "index_provider_taxonomies_on_code"
    t.index ["provider_id", "code"], name: "index_provider_taxonomies_on_provider_id_and_code", unique: true
  end

  create_table "providers", force: :cascade do |t|
    t.string "npi", null: false
    t.integer "entity_type"
    t.string "name"
    t.string "state"
    t.date "deactivated_on"
    t.date "reactivated_on"
    t.date "last_updated_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["npi"], name: "index_providers_on_npi", unique: true
    t.index ["state"], name: "index_providers_on_state"
  end

  add_foreign_key "provider_taxonomies", "providers"
end
