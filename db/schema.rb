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

ActiveRecord::Schema[7.0].define(version: 2023_06_16_191938) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "instruments", id: :serial, force: :cascade do |t|
    t.string "url"
    t.string "symbol"
    t.string "quote_url"
    t.string "fundamentals_url"
    t.string "robinhood_id"
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "instruments_stock_lists", id: false, force: :cascade do |t|
    t.integer "instrument_id", null: false
    t.integer "stock_list_id", null: false
  end

  create_table "robinhood_accounts", id: :serial, force: :cascade do |t|
    t.string "account_number"
    t.integer "robinhood_user_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "robinhood_users", id: :serial, force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "username"
    t.string "email"
    t.string "robinhood_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "stock_lists", id: :serial, force: :cascade do |t|
    t.string "name"
    t.integer "robinhood_account_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "group"
  end

end
