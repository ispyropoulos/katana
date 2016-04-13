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

ActiveRecord::Schema.define(version: 20160421071551) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "intarray"
  enable_extension "pg_stat_statements"

  create_table "branch_notification_settings", force: :cascade do |t|
    t.integer  "project_participation_id",             null: false
    t.integer  "tracked_branch_id"
    t.integer  "notify_on",                default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "branch_notification_settings", ["project_participation_id"], name: "index_branch_notification_settings_on_project_participation_id", using: :btree
  add_index "branch_notification_settings", ["tracked_branch_id"], name: "index_branch_notification_settings_on_tracked_branch_id", using: :btree

  create_table "docker_images", force: :cascade do |t|
    t.string "public_name",         default: "",         null: false
    t.string "hub_image",           default: "",         null: false
    t.string "standardized_name"
    t.string "version"
    t.text   "description",         default: "",         null: false
    t.string "type",                default: "language", null: false
    t.json   "docker_compose_data", default: {},         null: false
  end

  create_table "email_submissions", force: :cascade do |t|
    t.string "email", null: false
  end

  create_table "feedback_submissions", force: :cascade do |t|
    t.string  "category"
    t.text    "body"
    t.integer "rating"
    t.integer "user_id"
  end

  add_index "feedback_submissions", ["user_id"], name: "index_feedback_submissions_on_user_id", using: :btree

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id", null: false
    t.integer  "application_id",    null: false
    t.string   "token",             null: false
    t.integer  "expires_in",        null: false
    t.text     "redirect_uri",      null: false
    t.datetime "created_at",        null: false
    t.datetime "revoked_at"
    t.string   "scopes"
  end

  add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true, using: :btree

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id"
    t.string   "token",             null: false
    t.string   "refresh_token"
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",        null: false
    t.string   "scopes"
  end

  add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true, using: :btree
  add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id", using: :btree
  add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true, using: :btree

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",                      null: false
    t.string   "uid",                       null: false
    t.string   "secret",                    null: false
    t.text     "redirect_uri",              null: false
    t.string   "scopes",       default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "owner_id"
    t.string   "owner_type"
  end

  add_index "oauth_applications", ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type", using: :btree
  add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true, using: :btree

  create_table "project_files", force: :cascade do |t|
    t.integer  "project_id"
    t.string   "path",                    null: false
    t.string   "contents",   default: "", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "projects", force: :cascade do |t|
    t.integer  "user_id",                             null: false
    t.string   "repository_provider"
    t.integer  "repository_id"
    t.string   "repository_name"
    t.integer  "webhook_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "secure_random"
    t.string   "name",                default: "",    null: false
    t.string   "repository_owner",    default: "",    null: false
    t.integer  "docker_image_id"
    t.boolean  "in_demo_mode",        default: false, null: false
    t.string   "repository_slug"
    t.boolean  "is_private",          default: true,  null: false
  end

  add_index "projects", ["user_id", "repository_provider", "repository_id"], name: "index_projects_on_user_and_provider_and_repository_id", unique: true, using: :btree
  add_index "projects", ["user_id"], name: "index_projects_on_user_id", using: :btree

  create_table "projects_users", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "new_branch_notify_on", default: 0, null: false
  end

  add_index "projects_users", ["project_id"], name: "index_projects_users_on_project_id", using: :btree
  add_index "projects_users", ["user_id"], name: "index_projects_users_on_user_id", using: :btree

  create_table "technology_selections", force: :cascade do |t|
    t.integer  "project_id"
    t.integer  "docker_image_id"
    t.string   "version"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "technology_selections", ["docker_image_id"], name: "index_technology_selections_on_docker_image_id", using: :btree
  add_index "technology_selections", ["project_id"], name: "index_technology_selections_on_project_id", using: :btree

  create_table "test_jobs", force: :cascade do |t|
    t.integer  "test_run_id"
    t.string   "command",                                                     default: "",    null: false
    t.text     "result",                                                      default: "",    null: false
    t.integer  "status",                                                      default: 1,     null: false
    t.integer  "test_errors",                                                 default: 0,     null: false
    t.integer  "failures",                                                    default: 0,     null: false
    t.integer  "count",                                                       default: 0,     null: false
    t.integer  "assertions",                                                  default: 0,     null: false
    t.integer  "skips",                                                       default: 0,     null: false
    t.datetime "completed_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "before",                                                      default: "",    null: false
    t.text     "after",                                                       default: "",    null: false
    t.datetime "sent_at"
    t.decimal  "worker_in_queue_seconds",            precision: 10, scale: 6
    t.decimal  "worker_command_run_seconds",         precision: 10, scale: 6
    t.datetime "reported_at"
    t.integer  "chunk_index",                                                 default: 0,     null: false
    t.decimal  "avg_worker_command_run_seconds",     precision: 10, scale: 6
    t.decimal  "old_avg_worker_command_run_seconds", precision: 10, scale: 6
    t.string   "job_name"
    t.boolean  "rerun",                                                       default: false, null: false
    t.string   "worker_uuid"
  end

  create_table "test_runs", force: :cascade do |t|
    t.integer  "tracked_branch_id"
    t.string   "commit_sha"
    t.integer  "status",                    default: 0,  null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "commit_message"
    t.datetime "commit_timestamp"
    t.string   "commit_url"
    t.string   "commit_author_name"
    t.string   "commit_author_email"
    t.string   "commit_author_username"
    t.string   "commit_committer_name"
    t.string   "commit_committer_email"
    t.string   "commit_committer_username"
    t.text     "sha_history",               default: [], null: false, array: true
    t.integer  "run_index"
    t.integer  "project_id",                             null: false
    t.string   "setup_error",               default: "", null: false
  end

  add_index "test_runs", ["tracked_branch_id"], name: "index_test_runs_on_tracked_branch_id", using: :btree

  create_table "tracked_branches", force: :cascade do |t|
    t.integer  "project_id",  null: false
    t.string   "branch_name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "tracked_branches", ["project_id", "branch_name"], name: "index_tracked_branches_on_project_id_and_branch_name", unique: true, using: :btree
  add_index "tracked_branches", ["project_id"], name: "index_tracked_branches_on_project_id", using: :btree

  create_table "user_invitations", force: :cascade do |t|
    t.string   "token",       default: "", null: false
    t.integer  "project_id",               null: false
    t.integer  "user_id"
    t.string   "email",       default: "", null: false
    t.datetime "accepted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "user_invitations", ["project_id"], name: "index_user_invitations_on_project_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                                        default: "",    null: false
    t.string   "encrypted_password",                           default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                                default: 0,     null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.inet     "current_sign_in_ip"
    t.inet     "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.datetime "created_at",                                                   null: false
    t.datetime "updated_at",                                                   null: false
    t.string   "encrypted_github_access_token"
    t.string   "encrypted_github_access_token_salt"
    t.string   "encrypted_github_access_token_iv"
    t.boolean  "admin",                                        default: false
    t.integer  "projects_limit",                               default: 10,    null: false
    t.string   "provider"
    t.string   "uid"
    t.string   "encrypted_bitbucket_access_token"
    t.string   "encrypted_bitbucket_access_token_salt"
    t.string   "encrypted_bitbucket_access_token_iv"
    t.string   "encrypted_bitbucket_access_token_secret"
    t.string   "encrypted_bitbucket_access_token_secret_salt"
    t.string   "encrypted_bitbucket_access_token_secret_iv"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  create_table "worker_groups", force: :cascade do |t|
    t.integer "oauth_application_id",           null: false
    t.string  "friendly_name"
    t.text    "encrypted_ssh_key_private"
    t.string  "encrypted_ssh_key_private_salt"
    t.string  "encrypted_ssh_key_private_iv"
    t.text    "ssh_key_public"
    t.integer "ssh_key_provider_reference_id"
    t.integer "project_id",                     null: false
  end

  add_index "worker_groups", ["oauth_application_id"], name: "index_worker_groups_on_oauth_application_id", using: :btree

end
