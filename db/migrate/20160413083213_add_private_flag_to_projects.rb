class AddPrivateFlagToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :is_private, :boolean, default: true, null: false
  end
end
