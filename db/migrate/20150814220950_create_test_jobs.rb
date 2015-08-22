class CreateTestJobs < ActiveRecord::Migration
  def change
    create_table :test_jobs do |t|
      t.integer :tracked_branch_id, index: true
      t.string :commit_sha
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
