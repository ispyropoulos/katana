class AddRepositoryOwnerToProjectWizards < ActiveRecord::Migration
  def change
    add_column :project_wizards, :repository_owner, :string
  end
end
