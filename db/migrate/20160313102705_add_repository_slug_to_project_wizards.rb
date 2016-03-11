class AddRepositorySlugToProjectWizards < ActiveRecord::Migration
  def change
    add_column :project_wizards, :repository_slug, :string
  end
end
