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

ActiveRecord::Schema.define(version: 2017_10_06_050814) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "batch_entries", id: :serial, force: :cascade do |t|
    t.integer "batch_job_id"
    t.string "state", limit: 255
    t.text "result"
    t.index ["batch_job_id"], name: "index_batch_entries_on_batch_job_id"
  end

  create_table "batch_jobs", id: :serial, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "expires_at"
    t.string "on_complete_class", limit: 255
    t.text "on_complete_args"
    t.string "state", limit: 255
  end

  create_table "branches", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "commit_uri", limit: 255
    t.string "last_commit", limit: 255
    t.integer "repo_id"
    t.boolean "pull_request"
    t.datetime "last_checked_on"
    t.datetime "last_changed_on"
    t.text "commits_list"
    t.boolean "mergeable"
    t.string "merge_target"
    t.string "pr_title"
    t.integer "linter_offense_count"
  end

  create_table "repos", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
