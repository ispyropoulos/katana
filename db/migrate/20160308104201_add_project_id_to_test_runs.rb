class AddProjectIdToTestRuns < ActiveRecord::Migration
  def up
    add_column :test_runs, :project_id, :integer

    TestRun.reset_column_information
    sql = <<-SQL
      UPDATE test_runs SET project_id = tracked_branch_project_id
      FROM (SELECT test_runs.id test_run_id, tracked_branches.project_id tracked_branch_project_id
        FROM test_runs, tracked_branches
        WHERE test_runs.tracked_branch_id = tracked_branches.id) result
      WHERE result.test_run_id = test_runs.id
    SQL

    TestRun.connection.execute(sql)

    change_column :test_runs, :project_id, :integer, null: false
  end

  def down
    remove_column :test_runs, :project_id
  end
end
