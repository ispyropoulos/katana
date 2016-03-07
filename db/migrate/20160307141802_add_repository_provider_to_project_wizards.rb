class AddRepositoryProviderToProjectWizards < ActiveRecord::Migration
  def change
    add_column :project_wizards, :repository_provider, :string
  end
end
