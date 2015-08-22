class CreateTrackedBranches < ActiveRecord::Migration
  def change
    create_table :tracked_branches do |t|
      t.references :project, index: true, null: false
      t.string :branch_name

      t.timestamps
    end
    add_index :tracked_branches, [:project_id, :branch_name], unique: true
  end
end
