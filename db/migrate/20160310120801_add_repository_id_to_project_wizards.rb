class AddRepositoryIdToProjectWizards < ActiveRecord::Migration
  def change
    add_column :project_wizards, :repository_id, :integer
  end
end
