# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20150829093000) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "projects", force: :cascade do |t|
    t.integer  "user_id",             null: false
    t.string   "repository_provider"
    t.integer  "repository_id"
    t.string   "repository_name"
    t.integer  "webhook_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "projects", ["user_id", "repository_provider", "repository_id"], name: "index_projects_on_user_and_provider_and_repository_id", unique: true, using: :btree
  add_index "projects", ["user_id"], name: "index_projects_on_user_id", using: :btree

  create_table "test_job_files", force: :cascade do |t|
    t.integer  "test_job_id"
    t.string   "file_name",    default: "", null: false
    t.text     "result",       default: "", null: false
    t.integer  "status",       default: 0,  null: false
    t.integer  "test_errors",  default: 0,  null: false
    t.integer  "failures",     default: 0,  null: false
    t.integer  "count",        default: 0,  null: false
    t.integer  "assertions",   default: 0,  null: false
    t.integer  "skips",        default: 0,  null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_jobs", force: :cascade do |t|
    t.integer  "tracked_branch_id"
    t.string   "head_commit_id"
    t.integer  "status",            default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "test_jobs", ["tracked_branch_id"], name: "index_test_jobs_on_tracked_branch_id", using: :btree

  create_table "tracked_branches", force: :cascade do |t|
    t.integer  "project_id",  null: false
    t.string   "branch_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tracked_branches", ["project_id", "branch_name"], name: "index_tracked_branches_on_project_id_and_branch_name", unique: true, using: :btree
  add_index "tracked_branches", ["project_id"], name: "index_tracked_branches_on_project_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                              default: "",    null: false
    t.string   "encrypted_password",                 default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                      default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.boolean  "admin",                              default: false
    t.string   "encrypted_github_access_token"
    t.string   "encrypted_github_access_token_salt"
    t.string   "encrypted_github_access_token_iv"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
