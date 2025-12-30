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

ActiveRecord::Schema[8.1].define(version: 2025_12_30_213140) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.jsonb "activity_data"
    t.decimal "average_speed", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.decimal "distance", precision: 8, scale: 2
    t.integer "duration"
    t.integer "moving_time"
    t.string "name"
    t.string "pace"
    t.string "sport_type"
    t.datetime "start_date"
    t.string "strava_activity_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["start_date"], name: "index_activities_on_start_date"
    t.index ["strava_activity_id"], name: "index_activities_on_strava_activity_id", unique: true
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "strava_integrations", force: :cascade do |t|
    t.string "access_token"
    t.boolean "active", default: true
    t.jsonb "athlete_data"
    t.datetime "created_at", null: false
    t.datetime "last_sync_at"
    t.string "refresh_token"
    t.string "strava_athlete_id"
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["strava_athlete_id"], name: "index_strava_integrations_on_strava_athlete_id"
    t.index ["user_id"], name: "index_strava_integrations_on_user_id"
  end

  create_table "training_plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.text "goal"
    t.jsonb "plan_data"
    t.date "start_date"
    t.string "status", default: "active"
    t.integer "total_weeks"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["start_date"], name: "index_training_plans_on_start_date"
    t.index ["status"], name: "index_training_plans_on_status"
    t.index ["user_id"], name: "index_training_plans_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "goal"
    t.integer "height"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.integer "weight"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workouts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week"
    t.text "description"
    t.decimal "distance", precision: 8, scale: 2
    t.integer "duration"
    t.text "instructions"
    t.string "pace"
    t.date "scheduled_date"
    t.string "status", default: "pending"
    t.bigint "training_plan_id", null: false
    t.datetime "updated_at", null: false
    t.integer "week_number"
    t.jsonb "workout_details"
    t.string "workout_type"
    t.index ["scheduled_date"], name: "index_workouts_on_scheduled_date"
    t.index ["status"], name: "index_workouts_on_status"
    t.index ["training_plan_id", "week_number"], name: "index_workouts_on_training_plan_id_and_week_number"
    t.index ["training_plan_id"], name: "index_workouts_on_training_plan_id"
  end

  add_foreign_key "activities", "users"
  add_foreign_key "strava_integrations", "users"
  add_foreign_key "training_plans", "users"
  add_foreign_key "workouts", "training_plans"
end
