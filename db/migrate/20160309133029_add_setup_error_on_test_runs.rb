class AddSetupErrorOnTestRuns < ActiveRecord::Migration
  def change
    add_column :test_runs, :setup_error, :string, default: '', null: false
  end
end
