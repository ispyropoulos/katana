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

ActiveRecord::Schema.define(version: 20150911095957) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "amazon_power_providers", force: :cascade do |t|
    t.string  "cluster_arn"
    t.string  "task_arn"
    t.string  "service_arn"
    t.string  "docker_image",                  null: false
    t.integer "number_of_workers", default: 0, null: false
  end

  create_table "organization_roles", force: :cascade do |t|
    t.string "name", default: "", null: false
  end

  create_table "organization_user_roles", force: :cascade do |t|
    t.integer  "organization_id",      null: false
    t.integer  "user_id",              null: false
    t.integer  "organization_role_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "organization_user_roles", ["organization_id"], name: "index_organization_user_roles_on_organization_id", using: :btree
  add_index "organization_user_roles", ["organization_role_id"], name: "index_organization_user_roles_on_organization_role_id", using: :btree
  add_index "organization_user_roles", ["user_id"], name: "index_organization_user_roles_on_user_id", using: :btree

  create_table "organizations", force: :cascade do |t|
    t.integer  "user_id",    null: false
    t.string   "name",       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "organizations", ["user_id"], name: "index_organizations_on_user_id", using: :btree

  create_table "power_sources", force: :cascade do |t|
    t.integer "user_id",             null: false
    t.integer "power_provider_id"
    t.string  "power_provider_type"
  end

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
    t.integer  "user_id"
    t.string   "git_ref"
    t.integer  "status",           default: 0, null: false
    t.integer  "test_job_file_id", default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "test_jobs", ["test_job_file_id"], name: "index_test_jobs_on_test_job_file_id", using: :btree
  add_index "test_jobs", ["user_id"], name: "index_test_jobs_on_user_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "",    null: false
    t.string   "encrypted_password",     default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.boolean  "admin",                  default: false
    t.integer  "organizations_limit",    default: 0,     null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
