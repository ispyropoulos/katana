class ChangeDefaultStatusOnTestJobs < ActiveRecord::Migration
  def up
    change_column :test_jobs, :status, :integer, default: TestStatus::QUEUED
  end

  def down
    change_column :test_jobs, :status, :integer, default: 0
  end
end
