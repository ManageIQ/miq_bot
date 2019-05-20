# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2017_10_06_050814) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "batch_entries", force: :cascade do |t|
    t.bigint "batch_job_id"
    t.string "state", limit: 255
    t.text "result"
    t.index ["batch_job_id"], name: "index_batch_entries_on_batch_job_id"
  end

  create_table "batch_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.string "on_complete_class", limit: 255
    t.text "on_complete_args"
    t.string "state", limit: 255
  end

  create_table "branches", force: :cascade do |t|
    t.string "name", limit: 255
    t.string "commit_uri", limit: 255
    t.string "last_commit", limit: 255
    t.bigint "repo_id"
    t.boolean "pull_request"
    t.datetime "last_checked_on"
    t.datetime "last_changed_on"
    t.text "commits_list"
    t.boolean "mergeable"
    t.string "merge_target"
    t.string "pr_title"
    t.integer "linter_offense_count"
    t.index ["repo_id"], name: "index_branches_on_repo_id"
  end

  create_table "repos", force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
