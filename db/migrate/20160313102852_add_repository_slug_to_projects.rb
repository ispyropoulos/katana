class AddRepositorySlugToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :repository_slug, :string
  end
end
