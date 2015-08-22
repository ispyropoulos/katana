class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.references :user, index: true, null: false
      t.string :repository_provider
      t.integer :repository_id
      t.string :repository_name
      t.integer :webhook_id

      t.timestamps
    end
    add_index :projects, [:user_id, :repository_provider, :repository_id],
      unique: true, name: 'index_projects_on_user_and_provider_and_repository_id'
  end
end
