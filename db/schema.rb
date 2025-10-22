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

ActiveRecord::Schema[8.0].define(version: 2025_10_22_015939) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "timescaledb"

  create_table "follows", force: :cascade do |t|
    t.bigint "follower_id", null: false
    t.bigint "followed_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
  end

  create_table "sleep_records", primary_key: ["id", "clock_in_time"], force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "user_id", null: false
    t.timestamptz "clock_in_time", null: false
    t.datetime "clock_out_time"
    t.integer "duration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["clock_in_time"], name: "index_sleep_records_on_clock_in_time"
    t.index ["duration"], name: "index_sleep_records_on_duration"
    t.index ["user_id", "created_at"], name: "index_sleep_records_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_sleep_records_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "sleep_records", "users"
  create_hypertable "sleep_records", time_column: "clock_in_time", chunk_time_interval: "1 day", compress_segmentby: "", compress_orderby: "clock_in_time DESC", compress_after: "P7D"

  create_retention_policy "sleep_records", drop_after: "P30D"
end
